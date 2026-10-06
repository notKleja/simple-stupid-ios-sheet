import Flutter
import UIKit
import Darwin

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
    let channel = FlutterMethodChannel(name: "sheet_reference/metadata",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "capture" else { result(FlutterMethodNotImplemented); return }
      let window = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })
      guard let window else { result(FlutterError(code: "no_window",
        message: "No active presentation window", details: nil)); return }
      let screen = window.screen
      let size = window.bounds.size
      let safe = window.safeAreaInsets
      let traits = window.rootViewController?.traitCollection ?? window.traitCollection
      func sizeClass(_ value: UIUserInterfaceSizeClass) -> String {
        switch value { case .compact: return "compact"; case .regular: return "regular"
          default: return "unspecified" }
      }
      func sysctlString(_ name: String) -> String? {
        var length = 0
        guard sysctlbyname(name, nil, &length, nil, 0) == 0 else { return nil }
        var bytes = [CChar](repeating: 0, count: length)
        guard sysctlbyname(name, &bytes, &length, nil, 0) == 0 else { return nil }
        return String(cString: bytes)
      }
      #if targetEnvironment(simulator)
      let runtimeKind = "simulator"
      let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        ?? UIDevice.current.model
      let osBuild: Any = ProcessInfo.processInfo.environment["SIMULATOR_RUNTIME_BUILD_VERSION"]
        ?? ProcessInfo.processInfo.environment["SHEET_OS_BUILD"] as Any? ?? NSNull()
      #else
      let runtimeKind = "device"
      let model = sysctlString("hw.machine") ?? UIDevice.current.model
      let osBuild: Any = sysctlString("kern.osversion") as Any? ?? NSNull()
      #endif
      result([
        "documents_directory": FileManager.default.urls(for: .documentDirectory,
          in: .userDomainMask).first!.path,
        "os": ["version": UIDevice.current.systemVersion, "build": osBuild],
        "device": ["model": model, "runtime_kind": runtimeKind,
          "logical_size": ["width": size.width, "height": size.height],
          "physical_size": ["width": size.width * screen.scale,
            "height": size.height * screen.scale], "scale": screen.scale,
          "refresh_hz": screen.maximumFramesPerSecond,
          "refresh_hz_source": "UIScreen.maximumFramesPerSecond; measured cadence is per-frame"],
        "environment": ["orientation": size.height >= size.width ? "portrait" : "landscape",
          "safe_area": ["top": safe.top, "left": safe.left,
            "bottom": safe.bottom, "right": safe.right],
          "size_classes": ["horizontal": sizeClass(traits.horizontalSizeClass),
            "vertical": sizeClass(traits.verticalSizeClass)],
          "status_bar": ["hidden": window.windowScene?.statusBarManager?.isStatusBarHidden ?? false],
          "keyboard": ["visible": false, "frame": ["x": 0, "y": 0, "width": 0, "height": 0]],
          "system_settings": ["reduce_motion": UIAccessibility.isReduceMotionEnabled,
            "voice_over": UIAccessibility.isVoiceOverRunning,
            "content_size_category": traits.preferredContentSizeCategory.rawValue]]
      ])
    }
  }
}
