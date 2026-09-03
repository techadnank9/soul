import CoreLocation
import Flutter
import UIKit

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
