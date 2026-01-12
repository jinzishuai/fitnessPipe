/// Exponential Moving Average (EMA) smoother for reducing noise in signals.
///
/// Higher alpha values (closer to 1.0) make the filter more responsive
/// but less smooth. Lower values make it smoother but with more lag.
///
/// Recommended alpha values:
/// - 0.5: Fast movements, low latency, more noise
/// - 0.3: Normal/default, good balance
/// - 0.15: Very noisy inputs, higher latency
class AngleSmoother {
  /// Current smoothed value.
  double _smoothedValue = 0.0;

  /// Smoothing factor (0.0 - 1.0).
  ///
  /// Higher = more responsive, more noise.
  /// Lower = smoother, more lag.
  final double alpha;

  /// Whether the smoother has been initialized with at least one value.
  bool _isInitialized = false;

  AngleSmoother({this.alpha = 0.3}) {
    if (alpha < 0.0 || alpha > 1.0) {
      throw ArgumentError('Alpha must be between 0.0 and 1.0');
    }
  }

  /// Apply smoothing to a new raw value.
  ///
  /// The first value initializes the smoother. Subsequent values
  /// are blended using the EMA formula:
  /// ```
  /// smoothed = alpha * raw + (1 - alpha) * previous_smoothed
  /// ```
  double smooth(double rawValue) {
    if (!_isInitialized) {
      // First value: initialize without smoothing
      _smoothedValue = rawValue;
      _isInitialized = true;
    } else {
      // Apply EMA formula
      _smoothedValue = alpha * rawValue + (1.0 - alpha) * _smoothedValue;
    }

    return _smoothedValue;
  }

  /// Get the current smoothed value without updating.
  double get value => _smoothedValue;

  /// Reset the smoother to initial state.
  void reset() {
    _smoothedValue = 0.0;
    _isInitialized = false;
  }

  /// Whether this smoother has been initialized with data.
  bool get isInitialized => _isInitialized;
}
