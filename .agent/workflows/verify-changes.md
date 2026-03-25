---
description: Verify code changes compile and tests pass
---

After making any code changes, run this verification workflow:

// turbo-all

1. Analyze code for errors and warnings:
```bash
flutter analyze
```

2. Run root-level tests:
```bash
flutter test
```

3. Run package tests:
```bash
(cd packages/fitness_counter && flutter test)
```

4. Format code:
```bash
dart format lib/ test/ packages/ --set-exit-if-changed
```

If any step fails, fix the issues before proceeding.
