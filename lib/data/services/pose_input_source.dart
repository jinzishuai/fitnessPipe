import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// A single frame emitted by a pose input source.
class PoseInputFrame {
  const PoseInputFrame({
    required this.inputImage,
    this.previewFile,
    this.previewSize,
  });

  final InputImage inputImage;
  final File? previewFile;
  final Size? previewSize;
}

typedef PoseInputFrameCallback = void Function(PoseInputFrame frame);

/// Shared lifecycle contract for camera-like pose input sources.
abstract class PoseInputSource {
  Future<void> start(PoseInputFrameCallback onFrame);

  Future<void> stop();

  Future<void> dispose();

  int get sourceCount;

  Future<void> switchSource();

  bool get usesFilePreview;
}
