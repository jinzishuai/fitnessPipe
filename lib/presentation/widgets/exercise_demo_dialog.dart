import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'exercise_selector.dart';

/// Full-screen dialog that plays a looping instructional demo video
/// for the given [exerciseType].
///
/// The video is loaded from the bundled asset returned by
/// [ExerciseType.demoVideoAsset] and loops until the user dismisses
/// the dialog via the "X" button.
class ExerciseDemoDialog extends StatefulWidget {
  final ExerciseType exerciseType;

  const ExerciseDemoDialog({super.key, required this.exerciseType});

  @override
  State<ExerciseDemoDialog> createState() => _ExerciseDemoDialogState();
}

class _ExerciseDemoDialogState extends State<ExerciseDemoDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;

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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load demo video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
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
        child: Stack(
          children: [
            // Video content
            SizedBox(
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: _isInitialized
                    ? _controller.value.aspectRatio
                    : 16 / 9,
                child: _buildVideoContent(),
              ),
            ),

            // Title overlay (top-left)
            Positioned(
              top: 12,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
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

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return VideoPlayer(_controller);
  }
}
