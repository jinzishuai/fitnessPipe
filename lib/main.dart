import 'package:flutter/material.dart';

import 'presentation/screens/pose_detection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitnessPipeApp());
}

class FitnessPipeApp extends StatelessWidget {
  const FitnessPipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitnessPipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PoseDetectionScreen(),
    );
  }
}
