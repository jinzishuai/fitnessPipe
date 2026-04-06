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
    // EXPERIMENT: +50% transparency (alphas ×0.5) + stronger blur (38 vs 28).
    // Revert FitnessPipeTheme.dark to: overlayBackground 0x3E1C1C1E,
    // overlayBorder 0x24FFFFFF, overlayBlurSigma 28.0.
    overlayBackground: Color(0x1F1C1C1E),
    overlayBorder: Color(0x12FFFFFF),
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
    // EXPERIMENT: stronger frost (was 28) so text stays readable on very light fill.
    // Revert to 28.0 with the alpha revert above.
    overlayBlurSigma: 38.0,
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

/// Builds a glass-morphism container with blur backdrop and a subtle
/// liquid-glass specular highlight along the top edge.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showSpecular;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.showSpecular = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.fpTheme;
    final radius = borderRadius ?? theme.overlayRadius;
    final borderRadiusGeometry = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: borderRadiusGeometry,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: theme.overlayBlurSigma,
                sigmaY: theme.overlayBlurSigma,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor ?? theme.overlayBackground,
                  borderRadius: borderRadiusGeometry,
                  border: Border.all(
                    color: borderColor ?? theme.overlayBorder,
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
          if (showSpecular) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadiusGeometry,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      // EXPERIMENT: specular ×0.5 — revert to 0.18 / 0.05
                      colors: [
                        Colors.white.withValues(alpha: 0.09),
                        Colors.white.withValues(alpha: 0.025),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.22, 0.52],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadiusGeometry,
                    gradient: RadialGradient(
                      center: const Alignment(-0.82, -0.88),
                      radius: 1.05,
                      // EXPERIMENT: specular ×0.5 — revert to 0.10
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.48],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Padding(padding: padding ?? theme.overlayPadding, child: child),
        ],
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
    // EXPERIMENT: ×0.5 — revert AppBar to 0xA11C1C1E
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0x511C1C1E),
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
    // EXPERIMENT: FAB ×0.5 — revert bg 0x8F1C1C1E, side 0x24FFFFFF
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: const Color(0x481C1C1E),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0x12FFFFFF), width: 0.5),
      ),
    ),
    // EXPERIMENT: ×0.5 — revert popup 0x7D2C2C2E
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0x3E2C2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 15),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: seedColor,
      thumbColor: seedColor,
      overlayColor: seedColor.withValues(alpha: 0.2),
      inactiveTrackColor: const Color(0xFF3A3A3C),
    ),
    // EXPERIMENT: ×0.5 — revert dialog 0x982C2C2E
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0x4C2C2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    // EXPERIMENT: ×0.5 — revert sheet 0x982C2C2E
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0x4C2C2C2E),
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
