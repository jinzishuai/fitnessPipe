import 'package:flutter/material.dart';
import 'package:fitness_counter/fitness_counter.dart';
import 'real_lateral_raise.dart';
import 'real_single_squat.dart';

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

class ExerciseData {
  final String name;
  final List<PoseFrame> frames;
  final double Function(PoseFrame) calculateAngle;
  final double minValues;
  final double maxValues;

  ExerciseData({
    required this.name,
    required this.frames,
    required this.calculateAngle,
    this.minValues = 0,
    this.maxValues = 180,
  });
}

class PoseVisualizerPage extends StatefulWidget {
  const PoseVisualizerPage({super.key});

  @override
  State<PoseVisualizerPage> createState() => _PoseVisualizerPageState();
}

class _PoseVisualizerPageState extends State<PoseVisualizerPage> {
  int currentFrame = 0;
  bool isPlaying = false;
  late ExerciseData selectedExercise;
  late List<ExerciseData> exercises;

  @override
  void initState() {
    super.initState();
    
    exercises = [
      ExerciseData(
        name: 'Lateral Raise',
        frames: realLateralRaiseFrames,
        calculateAngle: (frame) => calculateAverageShoulderAngle(
          leftShoulder: frame[LandmarkId.leftShoulder],
          leftElbow: frame[LandmarkId.leftElbow],
          leftHip: frame[LandmarkId.leftHip],
          rightShoulder: frame[LandmarkId.rightShoulder],
          rightElbow: frame[LandmarkId.rightElbow],
          rightHip: frame[LandmarkId.rightHip],
        ),
      ),
      ExerciseData(
        name: 'Single Squat',
        frames: realSingleSquatFrames,
        calculateAngle: (frame) {
           // Using calculateAverageKneeAngle which we added to fitness_counter
           // We need to pass the required landmarks.
           // Note: calculateAverageKneeAngle might look for specific landmarks 
           // let's double check its signature.
           // It likely takes (leftHip, leftKnee, leftAnkle, rightHip, rightKnee, rightAnkle)
           // But wait, allow me to just use the one that takes named params if available
           // checking angle_calculator.dart from memory/previous reads:
           // it has calculateAverageKneeAngle({required leftHip, ..., required rightAnkle})
           
           return calculateAverageKneeAngle(
              leftHip: frame[LandmarkId.leftHip],
              leftKnee: frame[LandmarkId.leftKnee],
              leftAnkle: frame[LandmarkId.leftAnkle],
              rightHip: frame[LandmarkId.rightHip],
              rightKnee: frame[LandmarkId.rightKnee],
              rightAnkle: frame[LandmarkId.rightAnkle],
           );
        },
      ),
    ];
    
    selectedExercise = exercises[0];
    _playAnimation();
  }

  void _playAnimation() async {
    if (!isPlaying) return;

    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted && isPlaying) {
      setState(() {
        currentFrame = (currentFrame + 1) % selectedExercise.frames.length;
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
  
  void _onExerciseChanged(ExerciseData? newValue) {
      if (newValue != null) {
          setState(() {
              selectedExercise = newValue;
              currentFrame = 0;
              isPlaying = false;
          });
      }
  }

  @override
  Widget build(BuildContext context) {
    final frames = selectedExercise.frames;
    final frame = frames.isNotEmpty ? frames[currentFrame] : PoseFrame(landmarks: {}, timestamp: DateTime.now());
    // Safe guard if empty frames
    if (frames.isEmpty) return const Scaffold(body: Center(child: Text("No frames")));

    final angle = selectedExercise.calculateAngle(frame);

    // Calculate all angles for the graph
    final angles = frames.map((f) => selectedExercise.calculateAngle(f)).toList();
    final minAngle = angles.isEmpty ? 0.0 : angles.reduce((a, b) => a < b ? a : b);
    final maxAngle = angles.isEmpty ? 0.0 : angles.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Pose Data Visualizer'),
        actions: [
            DropdownButton<ExerciseData>(
                value: selectedExercise,
                icon: const Icon(Icons.arrow_downward),
                elevation: 16,
                onChanged: _onExerciseChanged,
                items: exercises.map<DropdownMenuItem<ExerciseData>>((ExerciseData value) {
                    return DropdownMenuItem<ExerciseData>(
                        value: value,
                        child: Text(value.name),
                    );
                }).toList(),
            ),
            const SizedBox(width: 16),
        ],
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
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 20),
                    Text(
                        'Range: ${minAngle.toStringAsFixed(1)}° - ${maxAngle.toStringAsFixed(1)}°',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey)),
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
                        divisions: frames.length > 1 ? frames.length - 1 : 1,
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
    if (frame.landmarks.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw skeleton connections
    _drawConnection(
        canvas, size, paint, LandmarkId.leftShoulder, LandmarkId.leftElbow);
    _drawConnection(
        canvas, size, paint, LandmarkId.leftElbow, LandmarkId.leftWrist);
    _drawConnection(
        canvas, size, paint, LandmarkId.rightShoulder, LandmarkId.rightElbow);
    _drawConnection(
        canvas, size, paint, LandmarkId.rightElbow, LandmarkId.rightWrist);
    _drawConnection(
        canvas, size, paint, LandmarkId.leftShoulder, LandmarkId.leftHip);
    _drawConnection(
        canvas, size, paint, LandmarkId.rightShoulder, LandmarkId.rightHip);
    _drawConnection(
        canvas, size, paint, LandmarkId.leftHip, LandmarkId.rightHip);
    _drawConnection(
        canvas, size, paint, LandmarkId.leftShoulder, LandmarkId.rightShoulder);
        
    // Legs
    _drawConnection(
        canvas, size, paint, LandmarkId.leftHip, LandmarkId.leftKnee);
    _drawConnection(
        canvas, size, paint, LandmarkId.leftKnee, LandmarkId.leftAnkle);
    _drawConnection(
        canvas, size, paint, LandmarkId.rightHip, LandmarkId.rightKnee);
    _drawConnection(
        canvas, size, paint, LandmarkId.rightKnee, LandmarkId.rightAnkle);

    // Draw landmarks
    for (final landmark in frame.landmarks.values) {
      final point = _scalePoint(landmark.x, landmark.y, size);
      canvas.drawCircle(point, 6, pointPaint);
    }
  }

  void _drawConnection(
      Canvas canvas, Size size, Paint paint, LandmarkId from, LandmarkId to) {
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
    
    if (angles.isEmpty) return;

    // Draw angle line
    final path = Path();
    for (int i = 0; i < angles.length; i++) {
      final x = (i / (angles.length - 1)) * size.width;
      final range = maxAngle - minAngle;
      final normalizedAngle = range == 0 ? 0.5 : (angles[i] - minAngle) / range;
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
      oldDelegate.currentFrame != currentFrame || oldDelegate.angles != angles;
}
