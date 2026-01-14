# FitnessPipe

**AI-Powered Fitness Tracking with Real-Time Pose Detection**

FitnessPipe is a cross-platform Flutter application that uses AI-powered pose estimation to track your exercise form in real-time. Built with Google ML Kit for pose detection, it works completely offline with all ML models bundled in the app.

![Flutter](https://img.shields.io/badge/Flutter-3.10.4+-02569B?logo=flutter)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20Android-lightgrey)

## ✨ Features

- 🎯 **Real-time Pose Detection** - Track 33 body landmarks using MediaPipe
- 📱 **Cross-Platform** - Runs on iOS, macOS, and Android
- 🔒 **Offline-First** - All ML models bundled, no internet required
- 🌏 **China-Compatible** - No Firebase or Google Cloud dependencies
- 🎨 **Live Skeleton Overlay** - Visual feedback of detected pose
- 📷 **Multi-Camera Support** - Front and back camera support with proper mirroring

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK**: 3.10.4 or higher
- **Dart SDK**: 3.10.4 or higher
- **Platform-specific tools**:
  - **iOS/macOS**: Xcode 14.0+, CocoaPods
  - **Android**: Android Studio, Android SDK 21+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/fitnessPipe.git
   cd fitnessPipe
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Install iOS/macOS pods** (if building for Apple platforms)
   ```bash
   cd ios && pod install && cd ..
   # or for macOS
   cd macos && pod install && cd ..
   ```

4. **Configure iOS Development Team** (required for iOS builds)
   ```bash
   # Copy the template
   cp ios/Config.local.xcconfig.template ios/Config.local.xcconfig
   
   # Edit ios/Config.local.xcconfig and replace YOUR_TEAM_ID with your Apple Developer Team ID
   # You can find your Team ID in Xcode > Preferences > Accounts
   ```

### Running the App

#### iOS (Physical Device or Simulator)

```bash
# List available devices
flutter devices

# Run on connected iPhone
flutter run -d <device-id>

# Or simply run on any available iOS device
flutter run
```

> **Note**: Make sure you've configured your development team in `ios/Config.local.xcconfig` (see Installation step 4).

#### macOS

```bash
flutter run -d macos
```

#### Android

```bash
# Run on connected Android device or emulator
flutter run -d <device-id>
```

### Building Release Versions

#### iOS

```bash
# Build without code signing (for CI/testing)
flutter build ios --no-codesign

# Build with code signing (for distribution)
flutter build ios
```

The built app will be at `build/ios/iphoneos/Runner.app`

#### macOS

```bash
flutter build macos
```

The built app will be at `build/macos/Build/Products/Release/fitness_pipe.app`

#### Android

```bash
# Build APK
flutter build apk

# Build App Bundle (for Play Store)
flutter build appbundle
```

The built APK will be at `build/app/outputs/flutter-apk/app-release.apk`

## 🛠️ Development

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── domain/                   # Business logic layer
│   ├── models/              # Data models (Pose, PoseLandmark)
│   └── interfaces/          # Abstract interfaces (PoseDetector)
├── data/                    # Data layer
│   └── ml_kit/             # ML Kit implementation
└── presentation/            # UI layer
    ├── screens/            # App screens
    └── widgets/            # Reusable widgets
```

### Code Quality Checks

Before committing any changes, run:

```bash
# Analyze code for errors and warnings
flutter analyze

# Run tests
flutter test

# Format code
dart format lib/ test/
```

Or use the verification workflow:

```bash
flutter analyze && flutter test && dart format lib/ test/ --set-exit-if-changed
```

### Architecture

FitnessPipe follows clean architecture principles with three main layers:

- **Presentation Layer**: Flutter UI widgets and screens
- **Domain Layer**: Business logic and data models
- **Data Layer**: ML Kit integration and pose detection implementation

The app uses an abstract `PoseDetector` interface, making it easy to swap ML backends in the future (e.g., native MediaPipe via FFI for better performance).

For detailed architecture documentation, see [docs/architecture.md](docs/architecture.md).

## 📋 Requirements

### Minimum Platform Versions

- **iOS**: 13.0+
- **macOS**: 10.14+
- **Android**: API 21+ (Android 5.0 Lollipop)

### Permissions

The app requires camera access:

- **iOS/macOS**: Camera permission is requested at runtime
- **Android**: Camera permission is declared in AndroidManifest.xml

## 🧪 Testing

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/unit/pose_detector_test.dart
```

### Package Tests (fitness_counter)

The exercise counting logic is isolated in the `packages/fitness_counter` directory. To run logic tests for counters (including lateral raise):

```bash
cd packages/fitness_counter
flutter test
```

To run a specific test file within the package:

```bash
cd packages/fitness_counter
flutter test test/lateral_raise_counter_test.dart
```

## 🤝 Contributing

Contributions are welcome! Please read [AGENTS.md](AGENTS.md) for development guidelines.

### Development Workflow

1. Create a feature branch
2. Make your changes
3. Run verification: `flutter analyze && flutter test`
4. Format code: `dart format lib/ test/`
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Google ML Kit** for pose detection
- **MediaPipe** for the pose estimation model
- **Flutter** team for the amazing framework

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [ML Kit Pose Detection](https://developers.google.com/ml-kit/vision/pose-detection)
- [Architecture Guide](docs/architecture.md)

## 🐛 Known Issues

- Front camera mirroring is handled automatically by the platform
- Build artifacts may contain `.mobileprovision` files (already gitignored)

## 📞 Support

For issues and questions, please open an issue on GitHub.

---

**Built with ❤️ using Flutter and ML Kit**
