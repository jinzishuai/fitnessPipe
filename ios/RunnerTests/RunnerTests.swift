import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testInfoPlistDeclaresFlutterSceneDelegate() {
    let plist = Bundle.main.infoDictionary

    let sceneManifest = plist?["UIApplicationSceneManifest"] as? [String: Any]
    let sceneConfigurations = sceneManifest?["UISceneConfigurations"] as? [String: Any]
    let applicationScenes =
      sceneConfigurations?["UIWindowSceneSessionRoleApplication"] as? [[String: Any]]
    let firstScene = applicationScenes?.first
    let delegateClassName = firstScene?["UISceneDelegateClassName"] as? String
    let productModuleName = plist?["CFBundleExecutable"] as? String

    XCTAssertNotNil(productModuleName, "CFBundleExecutable must be set in Info.plist")
    XCTAssertEqual(delegateClassName, "\(productModuleName!).SceneDelegate")
  }

}
