# Itadaki

The product spec and working rules are in @SPEC.md. Read it before changing anything.

## Status
- Phase 1 (MVP) is implemented, plus menu sections, page strips, the order summary and the card UI.
- Multi-page capture and SwiftData history are done. Not started: iPad split view (Phase 2); offline analyzer (Phase 3).
- History stores dishes as JSON inside `SavedPage` rather than as SwiftData models, so `Dish` stays a
  plain struct that the Linux tests can build. Changing `Dish`'s JSON keys breaks saved menus.

## Building and testing
- App (needs a Mac): `xcodegen generate && xcodebuild -scheme Itadaki -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Logic tests without Xcode (Linux or macOS): `swift test`. `Package.swift` compiles only the
  platform-neutral files listed in it; add new pure-logic files there, and keep UIKit/SwiftUI out of them.
- GitHub Actions (`.github/workflows/build.yml`) builds and tests on macOS on every push.

## Conventions
- `Dish`/`PageAnalysis` decoding is deliberately lenient about everything except names; keep
  `MenuPrompt.outputSchema` in step with it.
- Box coordinates: analyzers return boxes relative to the image they were sent; `TilePlan.merge`
  converts them to page coordinates. Everything in `MenuResult` is in page coordinates.
- Signing: put `DEVELOPMENT_TEAM = …` in `Config/Local.xcconfig` (gitignored). Never commit it.
