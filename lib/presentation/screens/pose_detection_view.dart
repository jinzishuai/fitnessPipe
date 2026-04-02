part of 'pose_detection_screen.dart';

extension _PoseDetectionScreenView on _PoseDetectionScreenState {
  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('FitnessPipe'),
        backgroundColor: Colors.black87,
        actions: [
          if (_canShowInputSelector)
            PopupMenuButton<PoseDetectionInputMode>(
              initialValue: _currentInputMode,
              icon: const Icon(Icons.cameraswitch),
              tooltip: 'Switch Input',
              onSelected: _handleInputModeSelection,
              itemBuilder: (context) => _availableInputModes
                  .map(
                    (mode) => PopupMenuItem<PoseDetectionInputMode>(
                      value: mode,
                      child: Row(
                        children: [
                          Icon(
                            _currentInputMode == mode
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(mode.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            icon: Icon(
              _currentPose != null ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {},
            tooltip: _currentPose != null ? 'Pose Detected' : 'No Pose',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isFilePreviewMode) {
      return _buildFilePreview();
    } else if (_isMacOS) {
      return _buildMacOSCameraPreview();
    } else {
      return _buildMobileCameraPreview();
    }
  }

  Widget _buildFilePreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_currentPreviewFrameFile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final double aspectRatio = _cameraImageSize != null
            ? _cameraImageSize!.width / _cameraImageSize!.height
            : 16 / 9;

        return Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.file(
                  _currentPreviewFrameFile!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
                if (_currentPose != null)
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: CustomPaint(
                      painter: SkeletonPainter(
                        pose: _currentPose,
                        rotationDegrees: 0,
                        imageSize: _cameraImageSize,
                        inputsAreRotated: false,
                        skeletonColor: Colors.greenAccent,
                        visibleLandmarks: _visibleLandmarks,
                        visibleBones: _visibleBones,
                        guide: _currentGuide,
                      ),
                    ),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Row(
                    children: [
                      ExerciseSelectorDropdown(
                        selectedExercise: _selectedExercise,
                        onChanged: _onExerciseSelected,
                      ),
                      if (_selectedExercise != null) ...[
                        const SizedBox(width: 8),
                        _buildExerciseActionButton(),
                      ],
                    ],
                  ),
                ),
                if (_selectedExercise != null)
                  RepCounterOverlay(
                    isActive: _phaseColor != Colors.grey,
                    repCount: _repCount,
                    phaseLabel: _phaseLabel,
                    phaseColor: _phaseColor,
                    currentAngle: _currentAngle,
                    startPrompt:
                        _selectedExercise?.config.startPositionPrompt ?? '',
                  ),
                if (_selectedExercise != null)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _resetCounter,
                      backgroundColor: Colors.black87,
                      child: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPose != null
                                ? Colors.greenAccent
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentPose != null
                              ? '$_filePreviewPoseLabel: ${(_currentPose!.confidence * 100).toStringAsFixed(0)}%'
                              : 'No pose detected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_displayedFeedback != null)
                  FormFeedbackOverlay(
                    feedback: FormFeedback(
                      status: _displayedFeedback!.status,
                      issues: [_displayedFeedback!.issue],
                    ),
                  ),
                if (_selectedExercise != null)
                  Positioned(
                    bottom: 16,
                    right: 80,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        _updateState(() {
                          _voiceGuidanceService.setEnabled(
                            !_voiceGuidanceService.isEnabled,
                          );
                        });
                      },
                      backgroundColor: Colors.black87,
                      child: Icon(
                        _voiceGuidanceService.isEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (_filePreviewBadgeLabel.isNotEmpty)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: _filePreviewBadgeColor,
                      child: Text(
                        _filePreviewBadgeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMacOSCameraPreview() {
    if (_macOSCameras == null || _macOSCameras!.isEmpty) {
      return const Center(
        child: Text(
          'No macOS cameras available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final selectedCamera = _macOSCameras![_selectedMacOSCameraIndex];

    return Stack(
      children: [
        Center(
          child: CameraMacOSView(
            key: _macOSCameraKey,
            deviceId: selectedCamera.deviceId,
            fit: BoxFit.contain,
            cameraMode: CameraMacOSMode.video,
            onCameraInizialized: _onMacOSCameraInitialized,
            onCameraDestroyed: () {
              _macOSCameraController = null;
              return const SizedBox.shrink();
            },
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Camera: ${selectedCamera.localizedName ?? selectedCamera.deviceId}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Pose detection requires iOS/Android device. '
                  'macOS shows camera preview only.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCameraPreview() {
    final controller = _mobileInputSource?.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final previewSize = controller.value.previewSize!;
    final double portraitAspectRatio = (previewSize.height < previewSize.width)
        ? previewSize.height / previewSize.width
        : previewSize.width / previewSize.height;
    final double landscapeAspectRatio = 1 / portraitAspectRatio;

    if (Platform.isIOS) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final double aspectRatio = isLandscape
              ? landscapeAspectRatio
              : portraitAspectRatio;

          return Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  mobile_camera.CameraPreview(controller),
                  if (_currentPose != null)
                    AspectRatio(
                      aspectRatio: aspectRatio,
                      child: CustomPaint(
                        painter: SkeletonPainter(
                          pose: _currentPose,
                          rotationDegrees: _sensorOrientation,
                          imageSize: null,
                          inputsAreRotated: false,
                          skeletonColor: Colors.greenAccent,
                          visibleLandmarks: _visibleLandmarks,
                          visibleBones: _visibleBones,
                          guide: _currentGuide,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Row(
                      children: [
                        ExerciseSelectorDropdown(
                          selectedExercise: _selectedExercise,
                          onChanged: _onExerciseSelected,
                        ),
                        if (_selectedExercise != null) ...[
                          const SizedBox(width: 8),
                          _buildExerciseActionButton(),
                        ],
                      ],
                    ),
                  ),
                  if (_selectedExercise != null)
                    RepCounterOverlay(
                      isActive: _phaseColor != Colors.grey,
                      repCount: _repCount,
                      phaseLabel: _phaseLabel,
                      phaseColor: _phaseColor,
                      currentAngle: _currentAngle,
                      startPrompt:
                          _selectedExercise?.config.startPositionPrompt ?? '',
                    ),
                  if (_displayedFeedback != null)
                    FormFeedbackOverlay(
                      feedback: FormFeedback(
                        status: _displayedFeedback!.status,
                        issues: [_displayedFeedback!.issue],
                      ),
                    ),
                  if (_selectedExercise != null)
                    Positioned(
                      bottom: 16,
                      right: 80,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          _updateState(() {
                            _voiceGuidanceService.setEnabled(
                              !_voiceGuidanceService.isEnabled,
                            );
                          });
                        },
                        backgroundColor: Colors.black87,
                        child: Icon(
                          _voiceGuidanceService.isEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_selectedExercise != null)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _resetCounter,
                        backgroundColor: Colors.black87,
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPose != null
                                  ? Colors.greenAccent
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentPose != null
                                ? 'Pose: ${(_currentPose!.confidence * 100).toStringAsFixed(0)}%'
                                : 'No pose detected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return NativeDeviceOrientationReader(
      useSensor: true,
      builder: (context) {
        final nativeOrientation = NativeDeviceOrientationReader.orientation(
          context,
        );

        int newDeviceRotation;
        bool isLandscape;
        switch (nativeOrientation) {
          case NativeDeviceOrientation.portraitUp:
            newDeviceRotation = 0;
            isLandscape = false;
            break;
          case NativeDeviceOrientation.landscapeLeft:
            newDeviceRotation = 90;
            isLandscape = true;
            break;
          case NativeDeviceOrientation.portraitDown:
            newDeviceRotation = 180;
            isLandscape = false;
            break;
          case NativeDeviceOrientation.landscapeRight:
            newDeviceRotation = 270;
            isLandscape = true;
            break;
          default:
            newDeviceRotation = 0;
            isLandscape = false;
        }

        final double aspectRatio = isLandscape
            ? landscapeAspectRatio
            : portraitAspectRatio;

        if (_deviceRotation != newDeviceRotation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateState(() {
                _deviceRotation = newDeviceRotation;
              });
            }
          });
        }
        final needsRotation = newDeviceRotation == 270;

        Widget previewWidget = Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Builder(
                  builder: (context) {
                    try {
                      final activeController = _mobileInputSource?.controller;
                      if (activeController == null ||
                          !activeController.value.isInitialized) {
                        return const SizedBox.shrink();
                      }
                      return mobile_camera.CameraPreview(activeController);
                    } catch (e) {
                      return const SizedBox.shrink();
                    }
                  },
                ),
                if (_currentPose != null)
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: CustomPaint(
                      painter: SkeletonPainter(
                        pose: _currentPose,
                        rotationDegrees:
                            (_sensorOrientation -
                                (newDeviceRotation == 180
                                    ? 0
                                    : newDeviceRotation) +
                                360) %
                            360,
                        imageSize: _cameraImageSize,
                        inputsAreRotated:
                            _getMobileImageRotation() !=
                            InputImageRotation.rotation0deg,
                        skeletonColor: Colors.greenAccent,
                        visibleLandmarks: _visibleLandmarks,
                        visibleBones: _visibleBones,
                        guide: _currentGuide,
                      ),
                    ),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Row(
                    children: [
                      ExerciseSelectorDropdown(
                        selectedExercise: _selectedExercise,
                        onChanged: _onExerciseSelected,
                      ),
                      if (_selectedExercise != null) ...[
                        const SizedBox(width: 8),
                        _buildExerciseActionButton(),
                      ],
                    ],
                  ),
                ),
                if (_selectedExercise != null)
                  RepCounterOverlay(
                    isActive: _phaseColor != Colors.grey,
                    repCount: _repCount,
                    phaseLabel: _phaseLabel,
                    phaseColor: _phaseColor,
                    currentAngle: _currentAngle,
                    startPrompt:
                        _selectedExercise?.config.startPositionPrompt ?? '',
                  ),
                if (_displayedFeedback != null)
                  FormFeedbackOverlay(
                    feedback: FormFeedback(
                      status: _displayedFeedback!.status,
                      issues: [_displayedFeedback!.issue],
                    ),
                  ),
                if (_selectedExercise != null)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _resetCounter,
                      backgroundColor: Colors.black87,
                      child: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ),
                if (_selectedExercise != null)
                  Positioned(
                    bottom: 16,
                    right: 80,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        _updateState(() {
                          _voiceGuidanceService.setEnabled(
                            !_voiceGuidanceService.isEnabled,
                          );
                        });
                      },
                      backgroundColor: Colors.black87,
                      child: Icon(
                        _voiceGuidanceService.isEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPose != null
                                ? Colors.greenAccent
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentPose != null
                              ? 'Pose: ${(_currentPose!.confidence * 100).toStringAsFixed(0)}%'
                              : 'No pose detected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (needsRotation) {
          return Transform.rotate(angle: 3.14159265359, child: previewWidget);
        }
        return previewWidget;
      },
    );
  }

  Widget _buildExerciseActionButton() {
    return IconButton(
      onPressed: _showThresholdSettings,
      icon: const Icon(Icons.settings, color: Colors.white),
      style: IconButton.styleFrom(backgroundColor: Colors.black87),
      tooltip: 'Settings',
    );
  }
}
