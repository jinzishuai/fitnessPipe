import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/exercise_type.dart';

/// Full-screen dialog that plays a looping instructional demo video
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

  // Auto-close countdown
  Timer? _countdownTimer;
  int _secondsRemaining = 6;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset(
      widget.exerciseType.demoVideoAsset,
    );

    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Start auto-close countdown once video is playing
        if (widget.autoClose) {
          _startCountdown();
        }
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
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicWidth(
          child: IntrinsicHeight(
            child: Stack(
              children: [
                // Video content — preserves native aspect ratio
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

                // Loading / error overlay
                if (!_isInitialized || _errorMessage != null)
                  Positioned.fill(child: _buildStatusOverlay()),

                // Title overlay (top-left)
                Positioned(
                  top: 12,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.exerciseType.displayName} Demo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Close button (top-right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child:
                            Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ),

                // Auto-close countdown (bottom-center)
                if (widget.autoClose && _isInitialized)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _secondsRemaining <= 3
                              ? 'Closing in $_secondsRemaining...'
                              : 'Auto-closing in $_secondsRemaining s',
                          style: TextStyle(
                            color: _secondsRemaining <= 3
                                ? Colors.orangeAccent
                                : Colors.white70,
                            fontSize: 14,
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

    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
}
