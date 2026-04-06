part of 'pose_detection_screen.dart';

extension _PoseDetectionScreenExercise on _PoseDetectionScreenState {
  void _processPoseWithCounter(Pose pose) {
    if (_selectedExercise == null) return;
    if (_isDemoShowing || _isSettingsShowing) return;

    final poseFrame = _poseAdapter.convert(pose);
    RepEvent? event;
    bool isWaiting = false;

    _updateState(() {
      if (_selectedExercise == ExerciseType.lateralRaise &&
          _lateralRaiseCounter != null) {
        event = _lateralRaiseCounter!.processPose(poseFrame);
        final state = _lateralRaiseCounter!.state;
        _repCount = state.repCount;
        _currentAngle = state.smoothedAngle;
        isWaiting = state.phase == LateralRaisePhase.waiting;

        final (label, color) = switch (state.phase) {
          LateralRaisePhase.waiting => ('Ready...', Colors.grey),
          LateralRaisePhase.down => ('Down', Colors.blue),
          LateralRaisePhase.rising => ('Rising ↑', Colors.orange),
          LateralRaisePhase.up => ('Up!', Colors.green),
          LateralRaisePhase.falling => ('Lowering ↓', Colors.orange),
        };
        _phaseLabel = label;
        _phaseColor = color;

        if (!isWaiting) {
          _processFormFeedback(
            _lateralRaiseFormAnalyzer?.analyzeFrame(poseFrame.landmarks),
          );
        }
      } else if (_selectedExercise == ExerciseType.singleSquat &&
          _singleSquatCounter != null) {
        event = _singleSquatCounter!.processPose(poseFrame);
        final state = _singleSquatCounter!.state;
        _repCount = state.repCount;
        _currentAngle = state.smoothedAngle;
        isWaiting = state.phase == SingleSquatPhase.waiting;

        final (label, color) = switch (state.phase) {
          SingleSquatPhase.waiting => ('Ready...', Colors.grey),
          SingleSquatPhase.standing => ('Standing', Colors.blue),
          SingleSquatPhase.descending => ('Descending ↓', Colors.orange),
          SingleSquatPhase.bottom => ('Bottom!', Colors.green),
          SingleSquatPhase.ascending => ('Ascending ↑', Colors.orange),
        };
        _phaseLabel = label;
        _phaseColor = color;

        if (!isWaiting) {
          _processFormFeedback(
            _singleSquatFormAnalyzer?.analyzeFrame(poseFrame.landmarks),
          );
        }
      } else if (_selectedExercise == ExerciseType.benchPress &&
          _benchPressCounter != null) {
        event = _benchPressCounter!.processPose(poseFrame);
        final state = _benchPressCounter!.state;
        _repCount = state.repCount;
        _currentAngle = state.smoothedAngle;
        isWaiting = state.phase == BenchPressPhase.waiting;

        final (label, color) = switch (state.phase) {
          BenchPressPhase.waiting => ('Ready...', Colors.grey),
          BenchPressPhase.up => ('Down ↓', Colors.blue),
          BenchPressPhase.falling => ('Lowering...', Colors.orange),
          BenchPressPhase.down => ('Up ↑', Colors.green),
          BenchPressPhase.rising => ('Pressing...', Colors.orange),
        };
        _phaseLabel = label;
        _phaseColor = color;

        if (!isWaiting) {
          _processFormFeedback(
            _benchPressFormAnalyzer?.analyzeFrame(poseFrame.landmarks),
          );
        }
      }
    });

    if (event is RepCompleted) {
      HapticFeedback.mediumImpact();
    }

    if (isWaiting && _selectedExercise != null) {
      _voiceGuidanceService.speakStartPrompt(
        _selectedExercise!.config.startPositionPrompt,
      );
    }
  }

  /// Shared form feedback processing: filters through cooldown, updates
  /// displayed feedback, triggers voice guidance, and schedules auto-clear.
  /// Called only when the exercise is actively counting (not in waiting phase).
  void _processFormFeedback(FormFeedback? feedback) {
    _currentFeedback = feedback;
    if (_currentFeedback == null || _feedbackCooldownManager == null) return;

    final filtered = _feedbackCooldownManager!.processFeedback(
      _currentFeedback!,
    );
    if (filtered != null) {
      _displayedFeedback = filtered;
      _voiceGuidanceService.speak(filtered);
      _feedbackClearTimer?.cancel();
      _feedbackClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _updateState(() {
            _displayedFeedback = null;
          });
        }
      });
    }
  }

  void _onExerciseSelected(ExerciseType? type) {
    _updateState(() {
      _selectedExercise = type;
      _lateralRaiseCounter = null;
      _lateralRaiseFormAnalyzer = null;
      _singleSquatCounter = null;
      _singleSquatFormAnalyzer = null;
      _benchPressCounter = null;
      _benchPressFormAnalyzer = null;
      _repCount = 0;
      _currentFeedback = null;
      _displayedFeedback = null;
      _phaseLabel = 'Ready';
      _phaseColor = Colors.grey;
      _currentAngle = 0.0;

      _feedbackCooldownManager?.reset();
      _feedbackClearTimer?.cancel();
      _voiceGuidanceService.resetStartPromptCooldown();
      if (type != null) {
        _feedbackCooldownManager = FeedbackCooldownManager(
          perCodeCooldown: type.config.feedbackCooldown,
        );
      } else {
        _feedbackCooldownManager = null;
      }

      if (type == ExerciseType.lateralRaise) {
        _lateralRaiseCounter = LateralRaiseCounter(
          topThreshold: _topThreshold,
          bottomThreshold: _bottomThreshold,
        );
        _lateralRaiseFormAnalyzer = LateralRaiseFormAnalyzer(
          sensitivity: _currentSensitivity,
        );
      } else if (type == ExerciseType.singleSquat) {
        _singleSquatCounter = SingleSquatCounter(
          topThreshold: _squatTopThreshold,
          bottomThreshold: _squatBottomThreshold,
        );
        _singleSquatFormAnalyzer = SingleSquatFormAnalyzer(
          sensitivity: _singleSquatSensitivity,
          standingThreshold: _squatTopThreshold,
        );
      } else if (type == ExerciseType.benchPress) {
        _benchPressCounter = BenchPressCounter(
          topThreshold: _benchPressTopThreshold,
          bottomThreshold: _benchPressBottomThreshold,
        );
        _benchPressFormAnalyzer = BenchPressFormAnalyzer(
          sensitivity: _benchPressSensitivity,
        );
      }

      if (_isVirtualCamera && type != null) {
        _virtualInputSource?.setExercise(type);
      }
    });

    if (type != null) {
      unawaited(_showDemoIfFirstTime(type));
    }
  }

  Future<void> _showExerciseDemo(
    ExerciseType type, {
    bool autoClose = false,
  }) async {
    if (!mounted) return;

    _updateState(() => _isDemoShowing = true);
    _voiceGuidanceService.stop();

    try {
      await showDialog(
        context: context,
        builder: (_) =>
            ExerciseDemoDialog(exerciseType: type, autoClose: autoClose),
      );
    } finally {
      if (mounted) {
        _updateState(() => _isDemoShowing = false);
      }
    }
  }

  Future<void> _showDemoIfFirstTime(ExerciseType type) async {
    final hasSeen = await _exerciseDemoService.hasSeenDemo(type);
    if (!hasSeen && mounted && _selectedExercise == type) {
      await _showExerciseDemo(type, autoClose: true);
      if (mounted) {
        await _exerciseDemoService.markDemoSeen(type);
      }
    }
  }

  Future<void> _showThresholdSettings() async {
    if (_selectedExercise == null) return;

    _updateState(() {
      _isSettingsShowing = true;
      _displayedFeedback = null;
      _feedbackClearTimer?.cancel();
    });
    _voiceGuidanceService.stop();

    double currentTop;
    double currentBottom;
    if (_selectedExercise == ExerciseType.lateralRaise) {
      currentTop = _topThreshold;
      currentBottom = _bottomThreshold;
    } else if (_selectedExercise == ExerciseType.singleSquat) {
      currentTop = _squatTopThreshold;
      currentBottom = _squatBottomThreshold;
    } else {
      currentTop = _benchPressTopThreshold;
      currentBottom = _benchPressBottomThreshold;
    }

    final exerciseType = _selectedExercise!;
    ThresholdDialogResult? result;
    try {
      result = await showThresholdSettingsSheet(
        context: context,
        initialTopThreshold: currentTop,
        initialBottomThreshold: currentBottom,
        exerciseType: exerciseType,
        initialSensitivity: exerciseType == ExerciseType.lateralRaise
            ? _currentSensitivity
            : exerciseType == ExerciseType.singleSquat
            ? _singleSquatSensitivity
            : exerciseType == ExerciseType.benchPress
            ? _benchPressSensitivity
            : null,
        onShowDemo: () => _showExerciseDemo(exerciseType),
      );
    } finally {
      if (mounted) {
        _updateState(() => _isSettingsShowing = false);
      }
    }

    if (result != null) {
      _updateState(() {
        final newTop = result!.topThreshold;
        final newBottom = result.bottomThreshold;

        if (_selectedExercise == ExerciseType.lateralRaise) {
          _topThreshold = newTop;
          _bottomThreshold = newBottom;
          _lateralRaiseCounter = LateralRaiseCounter(
            topThreshold: _topThreshold,
            bottomThreshold: _bottomThreshold,
          );

          if (result.sensitivity is LateralRaiseSensitivity) {
            _currentSensitivity =
                result.sensitivity! as LateralRaiseSensitivity;
            _lateralRaiseFormAnalyzer?.updateSensitivity(_currentSensitivity);
          }
        } else if (_selectedExercise == ExerciseType.singleSquat) {
          _squatTopThreshold = newTop;
          _squatBottomThreshold = newBottom;
          _singleSquatCounter = SingleSquatCounter(
            topThreshold: _squatTopThreshold,
            bottomThreshold: _squatBottomThreshold,
          );

          if (result.sensitivity is SingleSquatSensitivity) {
            _singleSquatSensitivity =
                result.sensitivity! as SingleSquatSensitivity;
            _singleSquatFormAnalyzer?.updateSensitivity(
              _singleSquatSensitivity,
            );
          }
        } else if (_selectedExercise == ExerciseType.benchPress) {
          _benchPressTopThreshold = newTop;
          _benchPressBottomThreshold = newBottom;
          _benchPressCounter = BenchPressCounter(
            topThreshold: _benchPressTopThreshold,
            bottomThreshold: _benchPressBottomThreshold,
          );

          if (result.sensitivity is BenchPressSensitivity) {
            _benchPressSensitivity =
                result.sensitivity! as BenchPressSensitivity;
            _benchPressFormAnalyzer?.updateSensitivity(_benchPressSensitivity);
          }
        }

        _repCount = 0;
        _phaseLabel = 'Ready';
        _phaseColor = Colors.grey;
        _currentAngle = 0.0;
      });
    }
  }

  void _resetCounter() {
    _updateState(() {
      _lateralRaiseCounter?.reset();
      _singleSquatCounter?.reset();
      _benchPressCounter?.reset();
      _lateralRaiseFormAnalyzer?.reset();
      _singleSquatFormAnalyzer?.reset();
      _benchPressFormAnalyzer?.reset();
      _feedbackCooldownManager?.reset();
      _feedbackClearTimer?.cancel();
      _repCount = 0;
      _displayedFeedback = null;
      _phaseLabel = 'Ready';
      _phaseColor = Colors.grey;
      _currentAngle = 0.0;
    });
  }
}
