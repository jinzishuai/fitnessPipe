import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "VideoFrameExtractorPlugin") {
      VideoFrameExtractorPlugin.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// SceneDelegate for UIScene lifecycle support on iOS
class SceneDelegate: NSObject, UISceneDelegate {
  func scene(
    _ scene: UIScene,
    connectToDevice url: URL
  ) -> Bool {
    return true
  }
  
  func scene(
    _ scene: UIScene,
    connection: UIScene.ConnectionOptions
  ) -> Bool {
    return true
  }
}