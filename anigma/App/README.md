Anigma macOS app entry and launch assets.
Invariants: preserve governed UI flows, keep entry points lightweight, no direct IO beyond service layers.

Entry points:
- `App/MacApp/AnigmaApp.swift` (app entry)
- `App/MacApp/Assets` (icons/branding)

Public surface:
- App entry bundle and launch configuration.

Build/test:
- `swift build --target AnigmaAppMacExecutable`

Related docs:
- `../llmdocs/06-mac-app.md`
- `../llmdocs/07-render-pipeline.md`
- `../llmdocs/18-build-and-release.md`
