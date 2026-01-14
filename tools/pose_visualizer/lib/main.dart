import 'package:flutter/material.dart';
import 'package:fitness_counter/fitness_counter.dart';
import 'real_lateral_raise.dart';

void main() {
  runApp(const PoseVisualizerApp());
}

class PoseVisualizerApp extends StatelessWidget {
  const PoseVisualizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Data Visualizer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PoseVisualizerPage(),
    );
  }
}

class PoseVisualizerPage extends StatefulWidget {
  const PoseVisualizerPage({super.key});

  @override
  State<PoseVisualizerPage> createState() => _PoseVisualizerPageState();
}

class _PoseVisualizerPageState extends State<PoseVisualizerPage> {
  int currentFrame = 0;
  bool isPlaying = false;

  final List<PoseFrame> frames = realLateralRaiseFrames;
  
  @override
  void initState() {
    super.initState();
    _playAnimation();
  }

  void _playAnimation() async {
    if (!isPlaying) return;
    
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted && isPlaying) {
      setState(() {
        currentFrame = (currentFrame + 1) % frames.length;
      });
      _playAnimation();
    }
  }

  void _togglePlayback() {
    setState(() {
      isPlaying = !isPlaying;
    });
    if (isPlaying) {
      _playAnimation();
    }
  }

  double _calculateAngle(PoseFrame frame) {
    return calculateAverageShoulderAngle(
      leftShoulder: frame[LandmarkId.leftShoulder],
      leftElbow: frame[LandmarkId.leftElbow],
      leftHip: frame[LandmarkId.leftHip],
      rightShoulder: frame[LandmarkId.rightShoulder],
      rightElbow: frame[LandmarkId.rightElbow],
      rightHip: frame[LandmarkId.rightHip],
    );
  }

  @override
  Widget build(BuildContext context) {
    final frame = frames[currentFrame];
    final angle = _calculateAngle(frame);
    
    // Calculate all angles for the graph
    final angles = frames.map((f) => _calculateAngle(f)).toList();
    final minAngle = angles.reduce((a, b) => a < b ? a : b);
    final maxAngle = angles.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Pose Data Visualizer'),
      ),
      body: Column(
        children: [
          // Pose visualization
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              child: CustomPaint(
                size: Size.infinite,
                painter: PosePainter(frame),
              ),
            ),
          ),
          
          // Angle graph
          Expanded(
            child: Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                size: Size.infinite,
                painter: AngleGraphPainter(
                  angles: angles,
                  currentFrame: currentFrame,
                  minAngle: minAngle,
                  maxAngle: maxAngle,
                ),
              ),
            ),
          ),
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Frame: ${currentFrame + 1}/${frames.length}',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 20),
                    Text('Angle: ${angle.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 20),
                    Text('Range: ${minAngle.toStringAsFixed(1)}° - ${maxAngle.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: currentFrame.toDouble(),
                        min: 0,
                        max: (frames.length - 1).toDouble(),
                        divisions: frames.length - 1,
                        onChanged: (value) {
                          setState(() {
                            currentFrame = value.toInt();
                            isPlaying = false;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _togglePlayback,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final PoseFrame frame;

  PosePainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw skeleton connections
    _drawConnection(canvas, size, paint, LandmarkId.leftShoulder, LandmarkId.leftElbow);
    _drawConnection(canvas, size, paint, LandmarkId.leftElbow, LandmarkId.leftWrist);
    _drawConnection(canvas, size, paint, LandmarkId.rightShoulder, LandmarkId.rightElbow);
    _drawConnection(canvas, size, paint, LandmarkId.rightElbow, LandmarkId.rightWrist);
    _drawConnection(canvas, size, paint, LandmarkId.leftShoulder, LandmarkId.leftHip);
    _drawConnection(canvas, size, paint, LandmarkId.rightShoulder, LandmarkId.rightHip);
    _drawConnection(canvas, size, paint, LandmarkId.leftHip, LandmarkId.rightHip);
    _drawConnection(canvas, size, paint, LandmarkId.leftShoulder, LandmarkId.rightShoulder);

    // Draw landmarks
    for (final landmark in frame.landmarks.values) {
      final point = _scalePoint(landmark.x, landmark.y, size);
      canvas.drawCircle(point, 6, pointPaint);
    }
  }

  void _drawConnection(Canvas canvas, Size size, Paint paint, LandmarkId from, LandmarkId to) {
    final fromLandmark = frame[from];
    final toLandmark = frame[to];
    
    if (fromLandmark != null && toLandmark != null) {
      final p1 = _scalePoint(fromLandmark.x, fromLandmark.y, size);
      final p2 = _scalePoint(toLandmark.x, toLandmark.y, size);
      canvas.drawLine(p1, p2, paint);
    }
  }

  Offset _scalePoint(double x, double y, Size size) {
    // MediaPipe coordinates are normalized 0-1
    return Offset(x * size.width, y * size.height);
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => oldDelegate.frame != frame;
}

class AngleGraphPainter extends CustomPainter {
  final List<double> angles;
  final int currentFrame;
  final double minAngle;
  final double maxAngle;

  AngleGraphPainter({
    required this.angles,
    required this.currentFrame,
    required this.minAngle,
    required this.maxAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final currentFramePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw angle line
    final path = Path();
    for (int i = 0; i < angles.length; i++) {
      final x = (i / (angles.length - 1)) * size.width;
      final normalizedAngle = (angles[i] - minAngle) / (maxAngle - minAngle);
      final y = size.height - (normalizedAngle * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw current frame marker
    final x = (currentFrame / (angles.length - 1)) * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      currentFramePaint,
    );

    // Draw min/max labels
    textPainter.text = TextSpan(
      text: '${maxAngle.toStringAsFixed(1)}°',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(5, 5));

    textPainter.text = TextSpan(
      text: '${minAngle.toStringAsFixed(1)}°',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(5, size.height - 20));
  }

  @override
  bool shouldRepaint(AngleGraphPainter oldDelegate) =>
      oldDelegate.currentFrame != currentFrame;
}
