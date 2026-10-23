# CUA Permission Kit

<img src="Assets/DemoIcon.png" width="96" alt="CUA Permission Demo flying saucer icon">

Native macOS permission cards and a draggable Settings handoff guide, extracted from Incodex.

**Independent community project. Not affiliated with or endorsed by OpenAI.**
CUA describes the computer-use workflow; this package does not ship OpenAI binaries, icons, or an authorization service.

[中文说明](README.zh-CN.md)

## What is included

- SwiftUI permission card hosted in AppKit.
- Draggable application row, System Settings window tracking, and arrow hints.
- Forward/back spring transitions, foreground snapshots, and RTL layout.
- Per-instance app URL, display name, app icon, permission icon, and localized copy.
- Typed user events and permission-state updates.

Swift Package Manager library. macOS 12+ deployment target. No external dependencies.
The deployment target is not a claim of runtime verification on every macOS version.

## Install locally

Add `.package(path: "../cua-permission-kit")` to your package dependencies and
`.product(name: "CUAPermissionKit", package: "cua-permission-kit")` to your target dependencies.
No remote release or version tag is required for local integration.

## Integration

Retain the presenter for the entire guide lifetime. Create and update it on the main actor.
The application owns permission checks, Settings opening, and cancellation of its own tasks.

```swift
import AppKit
import CUAPermissionKit

@MainActor
final class PermissionGuide {
    private var presenter: PermissionPresenter?

    func show(applicationURL: URL, applicationName: String) {
        presenter?.close()
        let configuration = PermissionConfiguration(
            applicationURL: applicationURL,
            applicationName: applicationName,
            permissions: [.deviceControl, .screenAndAudioRecording]
        )
        presenter = PermissionPresenter(
            configuration: configuration,
            onEvent: { [weak self] event in
                switch event {
                case .allow, .retry:
                    guard let settings = self?.presenter?.activePermission.settingsURL else { return }
                    if NSWorkspace.shared.open(settings) {
                        self?.presenter?.update(.awaitingUser)
                    } else {
                        self?.presenter?.update(.error)
                    }
                case .later, .close:
                    self?.close()
                }
            },
            onError: { [weak self] _ in self?.close() }
        )
        if presenter?.present() != true { close() }
    }

    // Call only after your application's real permission check succeeds.
    func permissionGranted() { presenter?.update(.granted) }

    func close() {
        presenter?.close()
        presenter = nil
    }
}
```

Clicking Allow, dragging an application, or opening Settings is **not** proof of authorization.
Only your real permission check may send `.granted`. Closing/Skip does not revoke permissions.
`.repairing` disables the repeated Allow flow while the caller prepares the handoff;
`.awaitingUser` starts Settings tracking; `.error` shows the configured error copy.
The current presenter emits `.allow`, `.retry`, and `.later` (including window close).
`.close` is reserved for host adapters.
`.error` is terminal for that attempt: close and create a new presenter to restart.
Cancel permission checks when closing or changing cards; do not deliver a stale result
for a previous `activePermission` to the current card.

### Customization

`PermissionConfiguration` accepts `applicationIcon`, `permissionIcon`, `rightToLeft`,
and `localizedCopy: [String: String]`. Missing copy keys use English defaults.
Supported keys:

`title`, `body`, `permissionTitle`, `permissionDescription`, `repair`, `later`, `back`,
`addedTitle`, `addedBody`, `dragInstruction`, `dragInstructionRuns`, `completeInSettings`,
`checking`, `repairing`, `openSettings`, `errorTitle`, `errorBody`, `granted`.

`dragInstructionRuns` is a JSON array of `{ "text": "…", "role": "primary" | "secondary" }`.
Its concatenated text must equal `dragInstruction`; invalid runs fall back to plain text.
Application identity always comes from configuration, not from localized strings.
Supply the exact localized application name in your custom drag instruction.

`managesActivationPolicy` defaults to `false`: the library does not change the host's Dock policy.
Enable it only in a dedicated short-lived helper process. Do not run multiple guide presenters
in that mode. Close the guide before releasing it or shutting down its host.

## Demo and verification

```sh
./script/build_and_run.sh
swift test
CUA_RUN_WINDOW_TESTS=1 swift test # interactive macOS session required
```

The Demo offers English, Chinese and RTL previews, two permission cards, a destination
selector, simulated results and **Restart**. Its default destination is the Demo drop
area. Dropping the exact Demo application URL simulates completion of the selected card:
it flies back, shows completed, and leaves the other card available. Completing both
closes the guide. Restart resets only the demonstration, never system permissions.
System Settings mode disables the Demo drop area; a simulated drop cannot complete
a real Settings flow. Explicit “Simulate” buttons remain test controls, not permission proof.

Select **System Settings** to use real Settings navigation. Changing the destination
restarts an existing preview, so helper geometry, instructions and completion rules
always use the displayed destination; system permissions are never reset.
The optional read-only check uses `AXIsProcessTrusted` or
`CGPreflightScreenCaptureAccess`; it never requests or resets authorization.
A screen-capture preflight is not a separate guarantee of audio-only authorization.
The app is staged in the user cache, not Desktop, to avoid a Desktop-folder access
request when AppKit creates the file drag's sandbox extension.

`permissions` defaults to `[.deviceControl]`. Supply both cases for two cards.
`language` selects version-aware permission names. `activePermission` identifies the
selected card. `.granted` completes that card after the return animation; the guide
closes only after all cards complete. `returnToCard()` returns without granting.
`PermissionHandoffTarget` supplies custom target geometry and activation; its default
is System Settings. See `Examples/CUAPermissionDemo` for the complete adapter.

## Scope and safety

The library presents state; the host owns real authorization checks. It contains no
TCC reset, privilege escalation, installer, networking, or OpenAI binaries.
The locator reads System Settings window geometry. Screen recording uses the system
recording icon when available, with an SF Symbol fallback; no Apple image is bundled.
The two permission kinds have distinct Settings routes. The original Incodex source
had only the Accessibility card wired up: the second card is an explicit extension,
not a claim to reproduce an unpublished CUA recording implementation.

The extracted card visual tokens and spring code remain unchanged. Radix colors,
0.5pt borders and centralized Demo tokens apply only to the control panel.
`ExtractionParityTests` fingerprints eight original visual/motion blocks, excluding
application-name injection and the multi-card default keyboard shortcut.
This is source-block parity, not full pixel parity across macOS versions.

Local acceptance on macOS 27.0.1 arm64: both real file drags into the Demo, independent
completion, return animation and restart passed; 20 tests passed including seven
opt-in window tests. Real system authorization changes, recording-specific Settings
placement, older OS versions and multi-monitor behavior remain separate acceptance gates.

## Attribution

Extracted from Incodex native macOS permission UI at
`c7340c97f4d9ecd7b0035f50bac1f526dc34e477`.
The existing MIT copyright notices are retained in [LICENSE](LICENSE).
This repository contains the extracted implementation, not OpenAI's proprietary CUA source.

Radix palette attribution is in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Demo icon

`Assets/DemoIcon.icon` is the editable Icon Composer source. It retains the supplied
flying-saucer path and the maintainer's black-and-white glass treatment. `DemoIcon.png`
is its exported preview; `DemoIcon.icns` is its compiled compatibility icon.
The Demo loads its own bundle icon rather than a placeholder symbol.
The run script compiles layered assets with Xcode 27; older toolchains use the static ICNS.
After changing the icon, save in Icon Composer, export the PNG, compile the ICNS with
`actool`, and update both exports together. The library has no dependency on these assets.

## Release boundary

This repository distributes a Swift source package. The Demo is a locally built example,
not a signed or notarized downloadable application. A first source preview must pass
release compilation, the external README integration build, CI and the opt-in window
suite. Real system authorization changes and broader OS/display acceptance are not
covered by those gates; do not describe this preview as a fully validated TCC adapter.
Tags and GitHub Releases require maintainer confirmation. No version tag is published yet.

## Library and Demo boundary

Dependencies flow one way: `DemoController → DemoSession → CUAPermissionKit`.
The controller composes Demo controls; the session owns target adaptation,
simulated results, and read-only probes. Demo tokens, icons, and drop targets
remain outside the library. Library and Demo tests use separate targets.

[Source comparison and outstanding checks](EXTRACTION_AUDIT.md).
