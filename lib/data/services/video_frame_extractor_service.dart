import 'package:flutter/services.dart';

class PreparedVideoSession {
  const PreparedVideoSession({
    required this.sessionId,
    required this.durationMs,
    required this.frameRate,
    required this.size,
  });

  final String sessionId;
  final int durationMs;
  final double frameRate;
  final Size size;
}

class ExtractedVideoFrame {
  const ExtractedVideoFrame({
    required this.filePath,
    required this.actualTimeMs,
  });

  final String filePath;
  final int actualTimeMs;
}

/// Bridges to the iOS frame extractor used for replaying picked videos.
class VideoFrameExtractorService {
  static const MethodChannel _channel = MethodChannel(
    'fitness_pipe/video_frames',
  );

  Future<PreparedVideoSession> prepareVideo(String path) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'prepareVideo',
      {'path': path},
    );
    if (result == null) {
      throw StateError('Video preparation returned no result.');
    }

    final width = (result['width'] as num?)?.toDouble();
    final height = (result['height'] as num?)?.toDouble();
    final sessionId = result['sessionId'] as String?;
    final durationMs = result['durationMs'] as int?;
    final frameRate = (result['frameRate'] as num?)?.toDouble();

    if (sessionId == null ||
        durationMs == null ||
        frameRate == null ||
        width == null ||
        height == null) {
      throw StateError('Video preparation returned incomplete metadata.');
    }

    return PreparedVideoSession(
      sessionId: sessionId,
      durationMs: durationMs,
      frameRate: frameRate,
      size: Size(width, height),
    );
  }

  Future<ExtractedVideoFrame> extractFrame({
    required String sessionId,
    required int timeMs,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'extractFrame',
      {'sessionId': sessionId, 'timeMs': timeMs},
    );
    if (result == null) {
      throw StateError('Frame extraction returned no result.');
    }

    final filePath = result['path'] as String?;
    final actualTimeMs = result['actualTimeMs'] as int?;
    if (filePath == null || actualTimeMs == null) {
      throw StateError('Frame extraction returned incomplete metadata.');
    }

    return ExtractedVideoFrame(filePath: filePath, actualTimeMs: actualTimeMs);
  }

  Future<void> disposeSession(String sessionId) async {
    await _channel.invokeMethod<void>('disposeVideo', {'sessionId': sessionId});
  }
}
