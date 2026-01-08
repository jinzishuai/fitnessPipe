# FitnessPipe Development Rules

These rules must be followed by the AI agent when developing this Flutter project.

## Code Quality

1. **Always verify compilation** after making code changes:
   ```bash
   flutter analyze
   ```

2. **Run tests** after implementing or modifying functionality:
   ```bash
   flutter test
   ```

3. **Format code** before committing:
   ```bash
   dart format lib/ test/
   ```

4. **Check for warnings** - treat warnings as errors. Fix all analyzer warnings before considering a change complete.

## Build Verification

1. **Build check for all platforms** when making platform-specific changes:
   ```bash
   flutter build ios --no-codesign
   flutter build macos
   flutter build apk
   ```

2. **Run on target platform** when touching UI or platform code:
   ```bash
   flutter run -d macos  # or ios/android
   ```

## Architecture Rules

1. **Never use Firebase** - this app must work in China without Google services.

2. **All ML models must be bundled** - no dynamic downloading from Google Play Services.

3. **Use the PoseDetector interface** for any pose detection work. Never directly import ML Kit classes in presentation or domain layers.

4. **Follow the project structure** defined in `docs/architecture.md`:
   - `lib/domain/` - interfaces and models only, no implementations
   - `lib/data/` - implementations of interfaces
   - `lib/features/` - feature-specific logic
   - `lib/presentation/` - UI widgets and screens

## Testing Requirements

1. **Write unit tests** for:
   - Angle calculations
   - Exercise detection logic
   - Form rules validation
   - Pose data transformations

2. **Skip ML tests on CI** - pose detection requires a real device. Use mock data for unit tests.

3. **Test both English and Chinese** feedback messages when modifying form correction.

## Performance Guidelines

1. **Never block the UI thread** with ML inference. Use Isolates for heavy processing.

2. **Limit frame processing rate** - if pose detection takes longer than frame interval, skip frames rather than queue them.

3. **Profile on low-end devices** before marking performance work complete.

## Platform-Specific

### iOS/macOS
- Test on physical device when touching camera code (simulators have limitations)
- Ensure camera entitlements are preserved

### Android
- Test on devices without Google Play Services
- Verify bundled model loads without network

## Git Practices

1. **Commit working code only** - every commit should pass `flutter analyze` and `flutter test`.

2. **Meaningful commit messages** - reference the feature area (e.g., "feat(exercise-counter): implement squat detection").

3. **No large binary files** - ML models should be managed separately if they're too large.
