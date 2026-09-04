import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../theme/soul_theme.dart';

/// The world, as coastlines to tap.
///
/// A hundred and seventy seven countries as longitude latitude rings, read
/// once from the bundle. The map shows the whole world first, divided into
/// continents; a tap on any country zooms to the continent it belongs to,
/// and a second tap inside the zoomed continent picks the country. The
/// projection, the continent split and the tap tolerance are Nouvel's first
/// onboarding, rebuilt here.
class CountryShape {
  const CountryShape({required this.name, required this.iso3, required this.polygons});

  final String name;
  final String iso3;

  /// Polygons, each a list of rings, each a list of [lon, lat] pairs.
  final List<List<List<List<double>>>> polygons;

  static CountryShape fromJson(Map<String, dynamic> json) => CountryShape(
        name: json['name'] as String,
        iso3: json['iso3'] as String,
        polygons: [
          for (final polygon in json['polygons'] as List)
            [
              for (final ring in polygon as List)
                [
                  for (final point in ring as List)
                    [for (final v in point as List) (v as num).toDouble()],
                ],
            ],
        ],
      );

  /// The polygon with the most vertices, standing in for the main landmass.
  /// Used for classifying and framing only, so an outlying territory does
  /// not skew which continent a country lands in.
  List<List<List<double>>> get mainPolygon {
    List<List<List<double>>>? best;
    var bestCount = -1;
    for (final polygon in polygons) {
      final count = polygon.fold<int>(0, (n, ring) => n + ring.length);
      if (count > bestCount) {
        bestCount = count;
        best = polygon;
      }
    }
    return best ?? const [];
  }
}

/// Read once, then held.
class WorldMapData {
  static Future<List<CountryShape>>? _loading;

  static Future<List<CountryShape>> load() {
    return _loading ??= rootBundle.loadString('assets/world_map.json').then((text) {
      final list = jsonDecode(text) as List;
      return [for (final item in list) CountryShape.fromJson(item as Map<String, dynamic>)];
    });
  }
}

enum Continent {
  africa('Africa'),
  asia('Asia'),
  europe('Europe'),
  northAmerica('North America'),
  southAmerica('South America'),
  oceania('Oceania'),
  antarctica('Antarctica');

  const Continent(this.label);
  final String label;
}

class MapRegion {
  const MapRegion(this.minLon, this.maxLon, this.minLat, this.maxLat);
  final double minLon, maxLon, minLat, maxLat;

  /// The populated band. Most of Antarctica and the Arctic ice cap are
  /// cropped out, so the inhabited world fills the frame.
  static const world = MapRegion(-180, 180, -60, 83);
}

abstract final class WorldMapGeometry {
  /// Equirectangular, one uniform scale, centred. Scaling each axis to fit
  /// would stretch every shape whenever the frame's ratio did not match
  /// the region's, which it usually does not.
  static Offset project(double lon, double lat, Size size, MapRegion region) {
    final lonSpan = region.maxLon - region.minLon;
    final latSpan = region.maxLat - region.minLat;
    final scale = math.min(size.width / lonSpan, size.height / latSpan);
    final offsetX = (size.width - lonSpan * scale) / 2;
    final offsetY = (size.height - latSpan * scale) / 2;
    return Offset(offsetX + (lon - region.minLon) * scale, offsetY + (region.maxLat - lat) * scale);
  }

  static Path pathFor(CountryShape shape, Size size, MapRegion region) {
    final path = Path();
    for (final polygon in shape.polygons) {
      for (final ring in polygon) {
        if (ring.isEmpty || ring.first.length != 2) continue;
        final first = project(ring.first[0], ring.first[1], size, region);
        path.moveTo(first.dx, first.dy);
        for (final point in ring.skip(1)) {
          if (point.length != 2) continue;
          final p = project(point[0], point[1], size, region);
          path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
    }
    return path;
  }

  /// A tap inside a shape wins. Otherwise the nearest shape whose closest
  /// vertex is within the tolerance, so a country a few points wide is
  /// still tappable.
  static CountryShape? resolve(Offset at, List<CountryShape> shapes, Size size, MapRegion region, {double tolerance = 14}) {
    for (final shape in shapes) {
      if (pathFor(shape, size, region).contains(at)) return shape;
    }
    CountryShape? closest;
    var closestDistance = double.infinity;
    for (final shape in shapes) {
      final bounds = pathFor(shape, size, region).getBounds().inflate(tolerance);
      if (!bounds.contains(at)) continue;
      var nearest = double.infinity;
      for (final polygon in shape.polygons) {
        for (final ring in polygon) {
          for (final point in ring) {
            if (point.length != 2) continue;
            final d = (project(point[0], point[1], size, region) - at).distance;
            if (d < nearest) nearest = d;
          }
        }
      }
      if (nearest <= tolerance && nearest < closestDistance) {
        closest = shape;
        closestDistance = nearest;
      }
    }
    return closest;
  }

  /// A ring whose own spread exceeds 180 degrees crosses the antimeridian,
  /// far eastern Russia and Fiji, and averaging it gives nonsense.
  static bool _spansAntimeridian(List<List<double>> ring) {
    var minLon = double.infinity, maxLon = -double.infinity;
    for (final p in ring) {
      if (p.length != 2) continue;
      if (p[0] < minLon) minLon = p[0];
      if (p[0] > maxLon) maxLon = p[0];
    }
    return maxLon - minLon > 180;
  }

  /// The plain mean of the main polygon's vertices. Enough to bucket a
  /// country into a continent or to place a label, not a true centroid.
  static (double lon, double lat) centroid(CountryShape shape) {
    var sumLon = 0.0, sumLat = 0.0;
    var count = 0;
    for (final ring in shape.mainPolygon) {
      if (_spansAntimeridian(ring)) continue;
      for (final p in ring) {
        if (p.length != 2) continue;
        sumLon += p[0];
        sumLat += p[1];
        count++;
      }
    }
    if (count == 0) return (0, 0);
    return (sumLon / count, sumLat / count);
  }

  static (double lon, double lat) averageCentroid(List<CountryShape> shapes) {
    if (shapes.isEmpty) return (0, 0);
    var lon = 0.0, lat = 0.0;
    for (final s in shapes) {
      final c = centroid(s);
      lon += c.$1;
      lat += c.$2;
    }
    return (lon / shapes.length, lat / shapes.length);
  }

  /// A rough split by centroid, not a rigorous one. It only decides which
  /// zoomed group a country appears in.
  static Continent continentAt(double lon, double lat) {
    if (lat < -60) return Continent.antarctica;
    if (lat < 25 && (lon > 110 || lon < -150)) return Continent.oceania;
    if (lon >= -170 && lon <= -30) return lat >= 13 ? Continent.northAmerica : Continent.southAmerica;
    if (lon >= -35 && lon < 52) {
      if (lat >= 35) return Continent.europe;
      if (lat < 12) return Continent.africa;
      return lon < 35 ? Continent.africa : Continent.asia;
    }
    return Continent.asia;
  }

  static Continent continentOf(CountryShape shape) {
    final c = centroid(shape);
    return continentAt(c.$1, c.$2);
  }

  /// A box trimmed to the second and ninety eighth percentile of each axis
  /// and padded a little, so a few far flung points cannot drag a whole
  /// continent's framing toward them.
  static MapRegion boundingRegion(List<CountryShape> shapes, {double padding = 4}) {
    final lons = <double>[];
    final lats = <double>[];
    for (final shape in shapes) {
      for (final ring in shape.mainPolygon) {
        if (_spansAntimeridian(ring)) continue;
        for (final p in ring) {
          if (p.length != 2) continue;
          lons.add(p[0]);
          lats.add(p[1]);
        }
      }
    }
    if (lons.isEmpty) return MapRegion.world;
    lons.sort();
    lats.sort();
    double pct(List<double> sorted, double p) => sorted[((sorted.length - 1) * p).round().clamp(0, sorted.length - 1)];
    final minLon = pct(lons, 0.02), maxLon = pct(lons, 0.98);
    final minLat = pct(lats, 0.02), maxLat = pct(lats, 0.98);
    if (minLon >= maxLon || minLat >= maxLat) return MapRegion.world;
    return MapRegion(
      minLon - padding,
      maxLon + padding,
      math.max(minLat - padding, -60),
      math.min(maxLat + padding, 83),
    );
  }
}

/// The map itself. Fills and strokes come from the caller, so the same
/// widget draws the world, a continent, and a chosen country.
class WorldMapView extends StatelessWidget {
  const WorldMapView({
    super.key,
    required this.shapes,
    required this.region,
    required this.onSelect,
    this.highlighted,
  });

  final List<CountryShape> shapes;
  final MapRegion region;
  final ValueChanged<CountryShape> onSelect;

  /// The iso3 of the country drawn in the accent.
  final String? highlighted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final hit = WorldMapGeometry.resolve(d.localPosition, shapes, size, region);
          if (hit != null) onSelect(hit);
        },
        child: ClipRect(
          child: CustomPaint(
            size: size,
            painter: _MapPainter(shapes: shapes, region: region, highlighted: highlighted),
          ),
        ),
      );
    });
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.shapes, required this.region, required this.highlighted});

  final List<CountryShape> shapes;
  final MapRegion region;
  final String? highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (final shape in shapes) {
      final chosen = shape.iso3 == highlighted;
      final path = WorldMapGeometry.pathFor(shape, size, region);
      fill.color = chosen ? SoulColors.clay.withValues(alpha: 0.4) : SoulColors.s1;
      stroke
        ..color = chosen ? SoulColors.clay : SoulColors.border2
        ..strokeWidth = chosen ? 1.2 : 0.5;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.shapes != shapes || old.region != region || old.highlighted != highlighted;
}
