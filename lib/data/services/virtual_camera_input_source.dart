import 'dart:io';

import 'pose_input_source.dart';
import '../../presentation/widgets/exercise_selector.dart';
import 'virtual_camera_service.dart';

/// Adapts the simulator virtual camera to the shared input source contract.
class VirtualCameraInputSource implements PoseInputSource {
  VirtualCameraInputSource({
    ExerciseType initialExercise = ExerciseType.lateralRaise,
  }) : _service = VirtualCameraService(initialExercise: initialExercise);

  final VirtualCameraService _service;

  @override
  int get sourceCount => 0;

  @override
  bool get usesFilePreview => true;

  ExerciseType get currentExercise => _service.currentExercise;

  void setExercise(ExerciseType type) {
    _service.setExercise(type);
  }

  @override
  Future<void> start(PoseInputFrameCallback onFrame) async {
    await _service.startStream((inputImage) {
      onFrame(
        PoseInputFrame(
          inputImage: inputImage,
          previewFile: inputImage.filePath != null
              ? File(inputImage.filePath!)
              : null,
          previewSize: _service.currentImageSize,
        ),
      );
    });
  }

  @override
  Future<void> stop() => _service.stopStream();

  @override
  Future<void> dispose() => _service.dispose();

  @override
  Future<void> switchSource() async {}
}
