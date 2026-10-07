import Flutter
import UIKit

// จุดเริ่มต้นฝั่ง iOS สำหรับเปิด Flutter app และลงทะเบียนปลั๊กอินของ Flutter
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // ลงทะเบียน plugin ให้ engine ใช้งานบริการ native ที่ Flutter packages ต้องการ
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
