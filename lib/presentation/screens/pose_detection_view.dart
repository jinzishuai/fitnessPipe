part of 'pose_detection_screen.dart';

extension _PoseDetectionScreenView on _PoseDetectionScreenState {
  Widget _buildScaffold() {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Initializing camera...',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'FitnessPipe',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyLarge,
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
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'FitnessPipe',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        ],
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

  CameraOverlay _buildOverlay() {
    return CameraOverlay(
      selectedExercise: _selectedExercise,
      onExerciseSelected: _onExerciseSelected,
      onShowSettings: _showThresholdSettings,
      onReset: _resetCounter,
      onToggleVoice: () {
        _updateState(() {
          _voiceGuidanceService.setEnabled(!_voiceGuidanceService.isEnabled);
        });
      },
      voiceEnabled: _voiceGuidanceService.isEnabled,
      isActive: _phaseColor != Colors.grey,
      repCount: _repCount,
      phaseLabel: _phaseLabel,
      phaseColor: _phaseColor,
      currentAngle: _currentAngle,
      startPrompt: _selectedExercise?.config.startPositionPrompt ?? '',
      displayedFeedback: _displayedFeedback,
      hasPose: _currentPose != null,
      poseConfidence: _currentPose?.confidence,
      poseLabel: _filePreviewPoseLabel,
      badgeLabel: _filePreviewBadgeLabel,
      badgeColor: _filePreviewBadgeColor,
      showInputSelector: _canShowInputSelector,
      currentInputMode: _currentInputMode,
      availableInputModes: _availableInputModes,
      onInputModeSelected: _handleInputModeSelection,
    );
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

        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth / aspectRatio,
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
                  ],
                ),
              ),
            ),
            _buildOverlay(),
          ],
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
      fit: StackFit.expand,
      children: [
        CameraMacOSView(
          key: _macOSCameraKey,
          deviceId: selectedCamera.deviceId,
          fit: BoxFit.cover,
          cameraMode: CameraMacOSMode.video,
          onCameraInizialized: _onMacOSCameraInitialized,
          onCameraDestroyed: () {
            _macOSCameraController = null;
            return const SizedBox.shrink();
          },
        ),
        _buildOverlay(),
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 48,
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

          return Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxWidth / aspectRatio,
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
                    ],
                  ),
                ),
              ),
              _buildOverlay(),
            ],
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

        return LayoutBuilder(
          builder: (context, constraints) {
            Widget cameraContent = FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth / aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Builder(
                      builder: (context) {
                        try {
                          final activeController =
                              _mobileInputSource?.controller;
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
                  ],
                ),
              ),
            );

            if (needsRotation) {
              cameraContent = Transform.rotate(
                angle: 3.14159265359,
                child: cameraContent,
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [cameraContent, _buildOverlay()],
            );
          },
        );
      },
    );
  }
}
