# Itadaki

The product spec and working rules are in @SPEC.md. Read it before changing anything.

## Status
- Phase 1 (MVP) is implemented. Phases 2–4 are not started.

## Building and testing
- App (needs a Mac): `xcodegen generate && xcodebuild -scheme Itadaki -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Logic tests without Xcode (Linux or macOS): `swift test`. `Package.swift` compiles only the
  platform-neutral files listed in it; add new pure-logic files there, and keep UIKit/SwiftUI out of them.
- GitHub Actions (`.github/workflows/build.yml`) builds and tests on macOS on every push.

## Conventions
- `Dish`/`PageAnalysis` decoding is deliberately lenient about everything except names; keep
  `MenuPrompt.outputSchema` in step with it.
- Signing: put `DEVELOPMENT_TEAM = …` in `Config/Local.xcconfig` (gitignored). Never commit it.
