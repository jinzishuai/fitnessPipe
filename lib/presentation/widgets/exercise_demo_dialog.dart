import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/exercise_type.dart';
import '../theme/app_theme.dart';

/// Overlay dialog that plays a looping instructional demo video
/// for the given [exerciseType].
///
/// When [autoClose] is true (first-time popup), the dialog automatically
/// closes after 6 seconds with a visible 3-2-1 countdown. The user can
/// still dismiss it early via the "X" button. When opened from the
/// settings help menu, [autoClose] should be false and the dialog stays
/// open until manually closed.
class ExerciseDemoDialog extends StatefulWidget {
  final ExerciseType exerciseType;

  /// If true, auto-closes after 6 seconds with a countdown.
  final bool autoClose;

  const ExerciseDemoDialog({
    super.key,
    required this.exerciseType,
    this.autoClose = false,
  });

  @override
  State<ExerciseDemoDialog> createState() => _ExerciseDemoDialogState();
}

class _ExerciseDemoDialogState extends State<ExerciseDemoDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _secondsRemaining = 6;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    if (widget.autoClose) {
      _startCountdown();
    }
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset(
      widget.exerciseType.demoVideoAsset,
    );

    try {
      await _controller.initialize().timeout(const Duration(seconds: 4));
      await _controller.setVolume(0.0);
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load demo video: $e';
        });
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
      });
      if (_secondsRemaining <= 0) {
        timer.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.fpTheme;

    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicWidth(
          child: IntrinsicHeight(
            child: Stack(
              children: [
                if (_isInitialized)
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                else
                  const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: SizedBox.expand(),
                  ),

                if (!_isInitialized || _errorMessage != null)
                  Positioned.fill(child: _buildStatusOverlay()),

                // Title overlay (top-left)
                Positioned(
                  top: 12,
                  left: 16,
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    borderRadius: 10,
                    child: Text(
                      '${widget.exerciseType.displayName} Demo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Close button (top-right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 20,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

                // Auto-close countdown
                if (widget.autoClose)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        borderRadius: 20,
                        child: Text(
                          _secondsRemaining <= 3
                              ? 'Closing in $_secondsRemaining...'
                              : 'Auto-closing in $_secondsRemaining s',
                          style: TextStyle(
                            color: _secondsRemaining <= 3
                                ? theme.feedbackWarning
                                : Colors.white70,
                            fontSize: 13,
                            fontWeight: _secondsRemaining <= 3
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}
