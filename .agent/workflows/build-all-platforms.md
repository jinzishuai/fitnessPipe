---
description: Build the app for all target platforms
---

Build the Flutter app for iOS, macOS, and Android to verify cross-platform compatibility.

1. Build for iOS (without code signing for CI):
```bash
flutter build ios --no-codesign
```

2. Build for macOS:
```bash
flutter build macos
```

3. Build for Android APK:
```bash
flutter build apk
```

Note: If a platform-specific build fails but others succeed, focus on fixing that platform before continuing.
