/// Exponential Moving Average (EMA) smoother for reducing noise in signals.
///
/// Higher alpha values (closer to 1.0) make the filter more responsive
/// but less smooth. Lower values make it smoother but with more lag.
///
/// Recommended alpha values:
/// - 0.5: Fast movements, low latency, more noise
/// - 0.3: Normal/default, good balance
/// - 0.15: Very noisy inputs, higher latency
///
/// ## Warm-up
///
/// On cold start the smoother can introduce significant lag because the
/// EMA needs several frames to converge from the first reading toward
/// the true signal. To avoid this, set [warmupFrames] to a positive
/// value — during the first [warmupFrames] calls to [smooth], the
/// filter effectively passes the raw values through (`alpha = 1.0`).
/// After the warm-up window the configured [alpha] takes over for
/// steady-state noise filtering.
class AngleSmoother {
  /// Current smoothed value.
  double _smoothedValue = 0.0;

  /// Smoothing factor (0.0 - 1.0).
  ///
  /// Higher = more responsive, more noise.
  /// Lower = smoother, more lag.
  final double alpha;

  /// Number of initial frames to pass through unsmoothed.
  ///
  /// During warm-up the smoother uses `alpha = 1.0` so that the
  /// output tracks the raw input immediately, eliminating cold-start
  /// lag. Set to 0 to disable warm-up (original behaviour).
  final int warmupFrames;

  /// Whether the smoother has been initialized with at least one value.
  bool _isInitialized = false;

  /// Number of frames processed so far (used for warm-up tracking).
  int _frameCount = 0;

  AngleSmoother({this.alpha = 0.3, this.warmupFrames = 0}) {
    if (alpha < 0.0 || alpha > 1.0) {
      throw ArgumentError('Alpha must be between 0.0 and 1.0');
    }
    if (warmupFrames < 0) {
      throw ArgumentError('warmupFrames must be >= 0');
    }
  }

  /// Apply smoothing to a new raw value.
  ///
  /// The first value initializes the smoother. Subsequent values
  /// are blended using the EMA formula:
  /// ```
  /// smoothed = effectiveAlpha * raw + (1 - effectiveAlpha) * previous_smoothed
  /// ```
  /// Where `effectiveAlpha` is `1.0` during the warm-up window and
  /// [alpha] afterwards.
  double smooth(double rawValue) {
    if (!_isInitialized) {
      // First value: initialize without smoothing
      _smoothedValue = rawValue;
      _isInitialized = true;
      _frameCount = 1;
    } else {
      _frameCount++;
      // During warm-up, use alpha=1.0 (raw passthrough) to avoid
      // cold-start lag. After warm-up, use the configured alpha.
      final effectiveAlpha = _frameCount <= warmupFrames ? 1.0 : alpha;
      _smoothedValue =
          effectiveAlpha * rawValue + (1.0 - effectiveAlpha) * _smoothedValue;
    }

    return _smoothedValue;
  }

  /// Get the current smoothed value without updating.
  double get value => _smoothedValue;

  /// Reset the smoother to initial state.
  void reset() {
    _smoothedValue = 0.0;
    _isInitialized = false;
    _frameCount = 0;
  }

  /// Whether this smoother has been initialized with data.
  bool get isInitialized => _isInitialized;

  /// Number of frames processed so far.
  int get frameCount => _frameCount;
}
