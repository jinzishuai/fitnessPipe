import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';

import 'pose_input_source.dart';
import 'video_frame_extractor_service.dart';

class LibraryVideoSelectionCanceled implements Exception {
  const LibraryVideoSelectionCanceled();

  @override
  String toString() => 'Video selection canceled';
}

/// Replays a picked library video as a real-time pose input source.
class LibraryVideoInputSource implements PoseInputSource {
  LibraryVideoInputSource({
    ImagePicker? imagePicker,
    VideoFrameExtractorService? extractor,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _extractor = extractor ?? VideoFrameExtractorService();

  final ImagePicker _imagePicker;
  final VideoFrameExtractorService _extractor;

  String? _selectedVideoPath;
  PreparedVideoSession? _session;
  Stopwatch? _playbackClock;
  bool _isStreaming = false;

  @override
  int get sourceCount => 1;

  @override
  bool get usesFilePreview => true;

  bool get hasSelectedVideo => _selectedVideoPath != null;

  Future<bool> pickVideo({bool forcePick = false}) async {
    if (_selectedVideoPath != null && !forcePick) return true;

    final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (video == null) return false;

    _selectedVideoPath = video.path;
    return true;
  }

  @override
  Future<void> start(PoseInputFrameCallback onFrame) async {
    final selectedVideoPath = _selectedVideoPath;
    if (selectedVideoPath == null) {
      throw const LibraryVideoSelectionCanceled();
    }
    if (!Platform.isIOS) {
      throw UnsupportedError('Library video replay is currently iOS-only.');
    }

    await stop();

    final session = await _extractor.prepareVideo(selectedVideoPath);
    _session = session;
    _isStreaming = true;
    _playbackClock = Stopwatch()..start();

    unawaited(_streamFrames(onFrame, session));
  }

  Future<void> _streamFrames(
    PoseInputFrameCallback onFrame,
    PreparedVideoSession session,
  ) async {
    final frameIntervalMs = math.max(16, (1000 / session.frameRate).round());

    while (_isStreaming &&
        _session?.sessionId == session.sessionId &&
        _playbackClock != null) {
      try {
        final elapsedMs = _playbackClock!.elapsedMilliseconds;
        final targetTimeMs = session.durationMs <= 0
            ? 0
            : elapsedMs % session.durationMs;
        final frame = await _extractor.extractFrame(
          sessionId: session.sessionId,
          timeMs: targetTimeMs,
        );
        if (!_isStreaming || _session?.sessionId != session.sessionId) {
          break;
        }

        onFrame(
          PoseInputFrame(
            inputImage: InputImage.fromFilePath(frame.filePath),
            previewFile: File(frame.filePath),
            previewSize: session.size,
          ),
        );

        final nextTickMs =
            ((elapsedMs ~/ frameIntervalMs) + 1) * frameIntervalMs;
        final delayMs = math.max(
          0,
          nextTickMs - _playbackClock!.elapsedMilliseconds,
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      } catch (error) {
        if (_isStreaming) {
          debugPrint('Library video stream error: $error');
          await stop();
        }
        break;
      }
    }
  }

  @override
  Future<void> stop() async {
    _isStreaming = false;
    _playbackClock?.stop();
    _playbackClock = null;

    final sessionId = _session?.sessionId;
    _session = null;
    if (sessionId != null) {
      await _extractor.disposeSession(sessionId);
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  @override
  Future<void> switchSource() async {}
}
