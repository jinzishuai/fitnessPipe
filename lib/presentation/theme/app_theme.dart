import 'dart:ui';

import 'package:flutter/material.dart';

/// Custom theme extension for FitnessPipe-specific design tokens.
@immutable
class FitnessPipeTheme extends ThemeExtension<FitnessPipeTheme> {
  final Color overlayBackground;
  final Color overlayBorder;
  final Color accentGreen;
  final Color poseDetectedColor;
  final Color poseNotDetectedColor;
  final Color feedbackGood;
  final Color feedbackWarning;
  final Color feedbackBad;
  final Color phaseReady;
  final Color phaseActive;
  final Color phaseTransition;
  final Color phaseComplete;
  final double overlayRadius;
  final double overlayBlurSigma;
  final EdgeInsets overlayPadding;

  const FitnessPipeTheme({
    required this.overlayBackground,
    required this.overlayBorder,
    required this.accentGreen,
    required this.poseDetectedColor,
    required this.poseNotDetectedColor,
    required this.feedbackGood,
    required this.feedbackWarning,
    required this.feedbackBad,
    required this.phaseReady,
    required this.phaseActive,
    required this.phaseTransition,
    required this.phaseComplete,
    required this.overlayRadius,
    required this.overlayBlurSigma,
    required this.overlayPadding,
  });

  static const dark = FitnessPipeTheme(
    overlayBackground: Color(0x801C1C1E),
    overlayBorder: Color(0x40FFFFFF),
    accentGreen: Color(0xFF30D158),
    poseDetectedColor: Color(0xFF30D158),
    poseNotDetectedColor: Color(0xFFFF453A),
    feedbackGood: Color(0xFF30D158),
    feedbackWarning: Color(0xFFFFD60A),
    feedbackBad: Color(0xFFFF453A),
    phaseReady: Color(0xFF8E8E93),
    phaseActive: Color(0xFF0A84FF),
    phaseTransition: Color(0xFFFF9F0A),
    phaseComplete: Color(0xFF30D158),
    overlayRadius: 16.0,
    overlayBlurSigma: 25.0,
    overlayPadding: EdgeInsets.all(16.0),
  );

  @override
  FitnessPipeTheme copyWith({
    Color? overlayBackground,
    Color? overlayBorder,
    Color? accentGreen,
    Color? poseDetectedColor,
    Color? poseNotDetectedColor,
    Color? feedbackGood,
    Color? feedbackWarning,
    Color? feedbackBad,
    Color? phaseReady,
    Color? phaseActive,
    Color? phaseTransition,
    Color? phaseComplete,
    double? overlayRadius,
    double? overlayBlurSigma,
    EdgeInsets? overlayPadding,
  }) {
    return FitnessPipeTheme(
      overlayBackground: overlayBackground ?? this.overlayBackground,
      overlayBorder: overlayBorder ?? this.overlayBorder,
      accentGreen: accentGreen ?? this.accentGreen,
      poseDetectedColor: poseDetectedColor ?? this.poseDetectedColor,
      poseNotDetectedColor: poseNotDetectedColor ?? this.poseNotDetectedColor,
      feedbackGood: feedbackGood ?? this.feedbackGood,
      feedbackWarning: feedbackWarning ?? this.feedbackWarning,
      feedbackBad: feedbackBad ?? this.feedbackBad,
      phaseReady: phaseReady ?? this.phaseReady,
      phaseActive: phaseActive ?? this.phaseActive,
      phaseTransition: phaseTransition ?? this.phaseTransition,
      phaseComplete: phaseComplete ?? this.phaseComplete,
      overlayRadius: overlayRadius ?? this.overlayRadius,
      overlayBlurSigma: overlayBlurSigma ?? this.overlayBlurSigma,
      overlayPadding: overlayPadding ?? this.overlayPadding,
    );
  }

  @override
  FitnessPipeTheme lerp(FitnessPipeTheme? other, double t) {
    if (other is! FitnessPipeTheme) return this;
    return FitnessPipeTheme(
      overlayBackground: Color.lerp(
        overlayBackground,
        other.overlayBackground,
        t,
      )!,
      overlayBorder: Color.lerp(overlayBorder, other.overlayBorder, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      poseDetectedColor: Color.lerp(
        poseDetectedColor,
        other.poseDetectedColor,
        t,
      )!,
      poseNotDetectedColor: Color.lerp(
        poseNotDetectedColor,
        other.poseNotDetectedColor,
        t,
      )!,
      feedbackGood: Color.lerp(feedbackGood, other.feedbackGood, t)!,
      feedbackWarning: Color.lerp(feedbackWarning, other.feedbackWarning, t)!,
      feedbackBad: Color.lerp(feedbackBad, other.feedbackBad, t)!,
      phaseReady: Color.lerp(phaseReady, other.phaseReady, t)!,
      phaseActive: Color.lerp(phaseActive, other.phaseActive, t)!,
      phaseTransition: Color.lerp(phaseTransition, other.phaseTransition, t)!,
      phaseComplete: Color.lerp(phaseComplete, other.phaseComplete, t)!,
      overlayRadius: lerpDouble(overlayRadius, other.overlayRadius, t)!,
      overlayBlurSigma: lerpDouble(
        overlayBlurSigma,
        other.overlayBlurSigma,
        t,
      )!,
      overlayPadding: EdgeInsets.lerp(overlayPadding, other.overlayPadding, t)!,
    );
  }
}

/// Helper to retrieve FitnessPipeTheme from context.
extension FitnessPipeThemeExtension on BuildContext {
  FitnessPipeTheme get fpTheme =>
      Theme.of(this).extension<FitnessPipeTheme>() ?? FitnessPipeTheme.dark;
}

/// Builds a glass-morphism container with blur backdrop.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.fpTheme;
    final radius = borderRadius ?? theme.overlayRadius;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: theme.overlayBlurSigma,
          sigmaY: theme.overlayBlurSigma,
        ),
        child: Container(
          padding: padding ?? theme.overlayPadding,
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.overlayBackground,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? theme.overlayBorder,
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Central theme builder for the app.
ThemeData buildAppTheme() {
  const seedColor = Color(0xFF30D158);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
    surface: const Color(0xFF000000),
    onSurface: Colors.white,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xE61C1C1E),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white, size: 22),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: const Color(0xCC1C1C1E),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0x33FFFFFF), width: 0.5),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xD92C2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 15),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: seedColor,
      thumbColor: seedColor,
      overlayColor: seedColor.withValues(alpha: 0.2),
      inactiveTrackColor: const Color(0xFF3A3A3C),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xF02C2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xF02C2C2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      dragHandleColor: Color(0xFF8E8E93),
      showDragHandle: true,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: -1.0,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: Colors.white),
      bodyMedium: TextStyle(fontSize: 13, color: Colors.white),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.white70,
      ),
    ),
    extensions: const [FitnessPipeTheme.dark],
  );
}
