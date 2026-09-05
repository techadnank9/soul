import CoreLocation
import Flutter
import UIKit
import WeatherKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerPlaceChannel(with: engineBridge.pluginRegistry)
    registerWeatherChannel(with: engineBridge.pluginRegistry)
  }

  /// The weather at a position, from Apple, on this device.
  ///
  /// WeatherKit rather than a weather service on the internet, because the
  /// membership already pays for it, it is licensed for a product people
  /// pay for, and the position never leaves the phone. Nothing about the
  /// weather goes through our own service at all.
  ///
  /// The condition comes back as Apple's own name for it, lower cased, and
  /// Dart turns that into the words somebody would use. The temperature is
  /// always Celsius here and converted there, so one place decides which
  /// unit a person is shown.
  private func registerWeatherChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "soul/weather") else { return }
    let channel = FlutterMethodChannel(name: "soul/weather", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "attribution" {
        if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
          UIApplication.shared.open(url)
        }
        result(nil)
        return
      }

      guard call.method == "now",
        let args = call.arguments as? [String: Any],
        let latitude = args["latitude"] as? Double,
        let longitude = args["longitude"] as? Double
      else {
        result(nil)
        return
      }

      guard #available(iOS 16.0, *) else {
        result(nil)
        return
      }

      Task {
        do {
          let weather = try await WeatherService.shared.weather(
            for: CLLocation(latitude: latitude, longitude: longitude),
            including: .current
          )
          result([
            "condition": String(describing: weather.condition).lowercased(),
            "celsius": weather.temperature.converted(to: .celsius).value,
            "daylight": weather.isDaylight,
          ])
        } catch {
          // No entitlement yet, no network, or Apple said no. The card is
          // simply not there, which is what home does with nothing.
          NSLog("weather: %@", error.localizedDescription)
          result(nil)
        }
      }
    }
  }

  /// Turns coordinates into a place a person would say: neighbourhood, city,
  /// state. Apple's geocoder, on the phone, so no package and no third party.
  private func registerPlaceChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "soul/place") else { return }
    let channel = FlutterMethodChannel(name: "soul/place", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "name",
        let args = call.arguments as? [String: Any],
        let latitude = args["latitude"] as? Double,
        let longitude = args["longitude"] as? Double
      else {
        result(nil)
        return
      }
      let location = CLLocation(latitude: latitude, longitude: longitude)
      CLGeocoder().reverseGeocodeLocation(location) { marks, _ in
        guard let mark = marks?.first else {
          result(nil)
          return
        }
        let parts = [mark.subLocality, mark.locality, mark.administrativeArea]
          .compactMap { $0 }
          .filter { !$0.isEmpty }
        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        result(unique.isEmpty ? nil : unique.joined(separator: ", "))
      }
    }
  }
}
