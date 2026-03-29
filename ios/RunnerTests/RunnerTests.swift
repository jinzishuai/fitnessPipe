import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testInfoPlistDeclaresFlutterSceneDelegate() throws {
    let infoPlistPath = Bundle(for: type(of: self))
      .bundlePath
      .replacingOccurrences(of: "/RunnerTests.xctest", with: "/Runner.app/Info.plist")
    let plist = NSDictionary(contentsOfFile: infoPlistPath)

    let sceneManifest = plist?["UIApplicationSceneManifest"] as? [String: Any]
    let sceneConfigurations = sceneManifest?["UISceneConfigurations"] as? [String: Any]
    let applicationScenes = sceneConfigurations?["UIWindowSceneSessionRoleApplication"] as? [[String: Any]]
    let firstScene = applicationScenes?.first
    let delegateClassName = firstScene?["UISceneDelegateClassName"] as? String

    XCTAssertEqual(delegateClassName, #"$(PRODUCT_MODULE_NAME).SceneDelegate"#)
  }

}
