part of 'pose_detection_screen.dart';

class _PoseDetectionScreenState extends State<PoseDetectionScreen>
    with WidgetsBindingObserver {
  // Pose detection
  late final PoseDetector _poseDetector;
  Pose? _currentPose;
  bool _isDetecting = false;

  // Exercise counter
  final _poseAdapter = PoseAdapter();
  ExerciseType? _selectedExercise;
  LateralRaiseCounter? _lateralRaiseCounter;
  LateralRaiseFormAnalyzer? _lateralRaiseFormAnalyzer;
  SingleSquatCounter? _singleSquatCounter;
  SingleSquatFormAnalyzer? _singleSquatFormAnalyzer;
  BenchPressCounter? _benchPressCounter;
  BenchPressFormAnalyzer? _benchPressFormAnalyzer;
  int _repCount = 0;
  String _phaseLabel = 'Ready';
  Color _phaseColor = Colors.grey;
  double _currentAngle = 0.0;
  FormFeedback? _currentFeedback;
  FilteredFeedback? _displayedFeedback;

  // Voice guidance and feedback throttling
  late final VoiceGuidanceService _voiceGuidanceService;
  FeedbackCooldownManager? _feedbackCooldownManager;
  Timer? _feedbackClearTimer;

  // Exercise demo / settings tracking
  final ExerciseDemoService _exerciseDemoService = ExerciseDemoService();
  bool _isDemoShowing = false;
  bool _isSettingsShowing = false;

  // Threshold configuration
  double _topThreshold = 60.0;
  double _bottomThreshold = 30.0;
  double _squatTopThreshold = 170.0;
  double _squatBottomThreshold = 160.0;
  SingleSquatSensitivity _singleSquatSensitivity =
      const SingleSquatSensitivity.defaults();
  LateralRaiseSensitivity _currentSensitivity =
      const LateralRaiseSensitivity.defaults();

  // Bench Press
  double _benchPressTopThreshold = 150.0;
  double _benchPressBottomThreshold = 90.0;
  BenchPressSensitivity _benchPressSensitivity =
      const BenchPressSensitivity.defaults();

  // UI state
  bool _isLoading = true;
  String? _errorMessage;
  Size? _cameraImageSize;
  int _sensorOrientation = 0;
  int _deviceRotation = 0;

  // Platform-specific camera handling
  final bool _isMacOS = Platform.isMacOS;
  bool _isVirtualCamera = false;
  MobileCameraInputSource? _mobileInputSource;
  VirtualCameraInputSource? _virtualInputSource;
  LibraryVideoInputSource? _libraryVideoInputSource;
  PoseDetectionInputMode? _currentInputMode;
  bool _isPickingLibraryVideo = false;
  File? _currentPreviewFrameFile;
  DateTime _lastPreviewFrameUpdate = DateTime(0);

  // macOS camera
  CameraMacOSController? _macOSCameraController;
  List<CameraMacOSDevice>? _macOSCameras;
  int _selectedMacOSCameraIndex = 0;
  GlobalKey? _macOSCameraKey;

  Set<LandmarkType>? get _visibleLandmarks {
    if (_selectedExercise == null) return null;
    return PoseAdapter.toLandmarkTypeSet(
      _selectedExercise!.config.visibleLandmarks,
    );
  }

  List<(LandmarkType, LandmarkType)>? get _visibleBones {
    if (_selectedExercise == null) return null;
    return PoseAdapter.toBoneConnections(
      _selectedExercise!.config.visibleBones,
    );
  }

  ExerciseGuide? get _currentGuide {
    if (_selectedExercise == ExerciseType.lateralRaise &&
        _lateralRaiseCounter != null) {
      return LateralRaiseGuide(
        topThreshold: _topThreshold,
        bottomThreshold: _bottomThreshold,
        currentPhase: _lateralRaiseCounter!.state.phase,
      );
    } else if (_selectedExercise == ExerciseType.singleSquat &&
        _singleSquatCounter != null) {
      return SingleSquatGuide(currentPhase: _singleSquatCounter!.state.phase);
    } else if (_selectedExercise == ExerciseType.benchPress &&
        _benchPressCounter != null) {
      return BenchPressGuide(currentPhase: _benchPressCounter!.state.phase);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _disposeScreen();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _handleAppLifecycleStateChange(state);
  }

  void _updateState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) => _buildScaffold();
}
