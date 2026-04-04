import 'package:flutter/material.dart';

import 'presentation/screens/pose_detection_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const FitnessPipeApp());
}

class FitnessPipeApp extends StatelessWidget {
  const FitnessPipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitnessPipe',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const PoseDetectionScreen(),
    );
  }
}
