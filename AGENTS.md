# AI Agent Guidelines for FitnessPipe

**Always read and follow the rules in [.agent/rules.md](.agent/rules.md) when working on this project.**

## Quick Reference

### Before Committing Any Code Change

We should fix any analysis errors and run tests before committing any code change. Also make sure the codes are properly formatted.

```bash
flutter analyze && flutter test && dart format lib/ test/ packages/ --set-exit-if-changed
```

### Key Constraints
- ❌ No Firebase or Google Cloud dependencies (China compatibility)
- ❌ No dynamic ML model downloading
- ✅ All models bundled in the app
- ✅ Use `PoseDetector` interface, never import ML Kit directly in UI

### Architecture
See [docs/architecture.md](docs/architecture.md) for full system design.

### Workflows
- `/verify-changes` - Run after code changes
- `/build-all-platforms` - Build for iOS, macOS, Android
