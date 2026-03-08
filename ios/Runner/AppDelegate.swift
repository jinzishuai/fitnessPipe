import AVFoundation
import Flutter
import UIKit

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

final class VideoFrameExtractorPlugin: NSObject, FlutterPlugin {
  private var sessions: [String: VideoFrameSession] = [:]

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "fitness_pipe/video_frames",
      binaryMessenger: registrar.messenger()
    )
    let instance = VideoFrameExtractorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "prepareVideo":
      handlePrepareVideo(call: call, result: result)
    case "extractFrame":
      handleExtractFrame(call: call, result: result)
    case "disposeVideo":
      handleDisposeVideo(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handlePrepareVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String
    else {
      result(
        FlutterError(code: "invalid_args", message: "Missing video path.", details: nil)
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let session = try VideoFrameSession(videoPath: path)
        let sessionId = UUID().uuidString

        let payload: [String: Any] = [
          "sessionId": sessionId,
          "durationMs": session.durationMs,
          "frameRate": session.frameRate,
          "width": session.size.width,
          "height": session.size.height,
        ]

        DispatchQueue.main.async {
          self.sessions[sessionId] = session
          result(payload)
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "prepare_failed",
              message: "Unable to prepare selected video.",
              details: String(describing: error)
            )
          )
        }
      }
    }
  }

  private func handleExtractFrame(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let sessionId = args["sessionId"] as? String,
      let timeMs = args["timeMs"] as? Int,
      let session = sessions[sessionId]
    else {
      result(
        FlutterError(code: "invalid_args", message: "Missing frame extraction args.", details: nil)
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let frame = try session.extractFrame(atMs: timeMs)
        let payload: [String: Any] = [
          "path": frame.path,
          "actualTimeMs": frame.actualTimeMs,
        ]
        DispatchQueue.main.async {
          result(payload)
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "extract_failed",
              message: "Unable to extract frame from selected video.",
              details: String(describing: error)
            )
          )
        }
      }
    }
  }

  private func handleDisposeVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let sessionId = args["sessionId"] as? String
    else {
      result(nil)
      return
    }

    sessions.removeValue(forKey: sessionId)?.dispose()
    result(nil)
  }
}

private final class VideoFrameSession {
  private static let maxRetainedFrames = 30

  struct ExtractedFrame {
    let path: String
    let actualTimeMs: Int
  }

  let durationMs: Int
  let frameRate: Double
  let size: CGSize

  private let generator: AVAssetImageGenerator
  private let workingDirectory: URL
  private var frameIndex = 0
  private var retainedFrames: [URL] = []

  init(videoPath: String) throws {
    let url = URL(fileURLWithPath: videoPath)
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw NSError(domain: "VideoFrameSession", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Video has no video track."
      ])
    }

    let transformedSize = track.naturalSize.applying(track.preferredTransform)
    self.size = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
    self.durationMs = max(1, Int(CMTimeGetSeconds(asset.duration) * 1000.0))
    let nominalFrameRate = Double(track.nominalFrameRate)
    self.frameRate = nominalFrameRate > 0 ? nominalFrameRate : 30.0

    self.generator = AVAssetImageGenerator(asset: asset)
    self.generator.appliesPreferredTrackTransform = true
    self.generator.requestedTimeToleranceBefore = .zero
    self.generator.requestedTimeToleranceAfter = .zero

    let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("fitness_pipe_video_frames", isDirectory: true)
    let sessionDirectory = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: sessionDirectory,
      withIntermediateDirectories: true
    )
    self.workingDirectory = sessionDirectory
  }

  func extractFrame(atMs timeMs: Int) throws -> ExtractedFrame {
    let boundedTimeMs = min(max(0, timeMs), max(0, durationMs - 1))
    let requestedTime = CMTime(value: CMTimeValue(boundedTimeMs), timescale: 1000)
    var actualTime = CMTime.zero
    let cgImage = try generator.copyCGImage(at: requestedTime, actualTime: &actualTime)
    let image = UIImage(cgImage: cgImage)
    guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
      throw NSError(domain: "VideoFrameSession", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "Failed to encode JPEG frame."
      ])
    }

    let frameURL = workingDirectory.appendingPathComponent("frame_\(frameIndex).jpg")
    try jpegData.write(to: frameURL, options: .atomic)
    frameIndex += 1
    retainedFrames.append(frameURL)
    trimRetainedFrames()

    let actualTimeMs = Int(CMTimeGetSeconds(actualTime) * 1000.0)
    return ExtractedFrame(path: frameURL.path, actualTimeMs: actualTimeMs)
  }

  func dispose() {
    try? FileManager.default.removeItem(at: workingDirectory)
  }

  private func trimRetainedFrames() {
    while retainedFrames.count > VideoFrameSession.maxRetainedFrames {
      let oldFrame = retainedFrames.removeFirst()
      try? FileManager.default.removeItem(at: oldFrame)
    }
  }
}
