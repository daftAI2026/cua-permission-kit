# CUA Permission Kit

**English** | [简体中文](README.zh-CN.md)

<img src="Assets/DemoIcon.png" width="128" height="128" alt="CUA Permission Kit black-and-white flying saucer logo">

A Swift package for macOS permission onboarding, extracted from Incodex. It renders
device-control and screen-recording cards, guides users to System Settings, and
displays the permission state supplied by the host application.

**Independent community project. Not affiliated with or endorsed by OpenAI.**
CUA describes the computer-use workflow; this package does not ship OpenAI binaries, icons, or an authorization service.

[![Demo: drag both permission cards and restart](Assets/Demo.gif)](Assets/Demo.mp4)

[Watch MP4](Assets/Demo.mp4) | 11.2s | 1080p

## Features

- Two cards: Device Control & Data Access, and Screen & System Audio Recording.
- Older macOS versions show Accessibility and Screen Recording where applicable.
- Single-card integration by default; enable both cards through `permissions`.
- Original card tokens, draggable application row, and spring animations preserved.
- Recording icon loaded from the system, with an SF Symbol fallback.
- Separate Demo controls using Radix color scales and centralized tokens.

Swift Package Manager library. macOS 12+ deployment target. No external dependencies.
The deployment target is not a claim of runtime verification on every macOS version.

## Quick Start

Clone the repository and run the Demo with Xcode command-line tools available:

```sh
git clone https://github.com/daftAI2026/cua-permission-kit.git
cd cua-permission-kit
./script/build_and_run.sh
```

The Demo starts in simulation mode. Choose **System Settings** to inspect real
permissions. See [Demo](#demo) for the distinction.

See [Integration](#integration) for the complete example and API reference.

Verification commands:

```sh
swift test
CUA_RUN_WINDOW_TESTS=1 swift test # Requires an interactive macOS session
swift build -c release
```

### Add the library

Add `.package(path: "../cua-permission-kit")` to your package dependencies and
`.product(name: "CUAPermissionKit", package: "cua-permission-kit")` to your target dependencies.
No remote release or version tag is required for local integration.

## When to show the guide

**We recommend completing authorization before the first main-app launch** when an
installer or launcher provides onboarding. For an embedded guide, show it first; start screen
capture and automation only after the host process confirms access.

Authorize the **final signed and installed app**, not its installer or helper.
Helper permissions do not authorize the main app. Re-signing or keeping duplicate
bundles with the same ID can invalidate access.

Early onboarding can reduce extra restarts, but does not eliminate them.
Follow any macOS request to quit and reopen, especially for screen recording.

## Safety

The host checks authorization; the library displays the result. A click or file drop
is not proof of access. The library does not reset TCC or request elevated privileges.

The Demo is built locally and is not Apple-notarized. Older macOS versions and
multi-monitor placement remain unverified. See [verification details](EXTRACTION_AUDIT.md).

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

`permissions` defaults to `[.deviceControl]`; supply both cases for two cards.
`activePermission` identifies the selected card. `.granted` completes it after the
return animation; `returnToCard()` returns without granting access.
`PermissionHandoffTarget` configures target geometry and activation (default: System Settings).

### Customization

`PermissionConfiguration` accepts `applicationIcon`, `permissionIcon`, `rightToLeft`,
and `localizedCopy: [String: String]`. `language` selects built-in permission names
and drag instructions; supply `localizedCopy` for the remaining interface text.
Untranslated keys retain their defaults, which can be English.
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

## Demo

- **Demo**: drag the application into the drop area to simulate completion. No system permissions change.
- **System Settings**: open the selected permission page. The optional read-only probe checks actual access; simulation buttons are not proof of authorization.
- **Restart**: reset the preview, not system permissions.

Each card returns independently; completing both closes the guide. The recording
probe checks screen-capture access, not a separate audio-only permission.

Set `DemoSession.applicationName` to change the displayed name (default: `"Demo"`).
See [the Demo source](Examples/CUAPermissionDemo) for the complete host adapter.

## Opening a trusted, unnotarized Demo

No Developer ID-signed, Apple-notarized Demo is distributed by this project. A local
Apple Development certificate, when available, is only a development signing identity;
it does not make the Demo a notarized distribution. No Apple developer membership
is required to build the source. To explicitly build with ad-hoc signing:

```sh
CUA_DEMO_SIGN_IDENTITY=- ./script/build_and_run.sh
```

If macOS blocks a **downloaded copy you have verified and trust**, the following steps
remove the quarantine attribute and apply a new ad-hoc signature **to that Demo only**.
This is not “removing the signature” and does not grant Accessibility or recording
access. Do not run it for an app that already opens correctly, an untrusted download,
or an app whose existing Developer ID signature you need to preserve.

Quit the Demo first. Set `APP` to the exact copy you intend to run; this is the local
build script's output path:

```sh
APP="$HOME/Library/Caches/org.cuapermissionkit.demo/CUAPermissionDemo.app"
xattr -dr com.apple.quarantine "$APP"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
open "$APP"
```

Run this, if needed, **before** permission onboarding: re-signing changes the app's
identity and may require granting access again. No `sudo`, global Gatekeeper change,
`codesign --remove-signature`, or TCC reset is needed. If Settings shows an enabled
stale Demo entry but the probe remains false, first confirm the running bundle path;
remove and re-add only that Demo entry, never reset other apps' permissions.

## Contributing

Read [AGENTS.md](AGENTS.md) for repository boundaries, development commands and
verification requirements. Keep changes scoped and include a regression test for
behavior changes. Report the macOS version, build commit and selected Demo target
when filing a reproducible issue; omit credentials and private screen contents.

## License

Extracted from Incodex under MIT. See [LICENSE](LICENSE),
[third-party notices](THIRD_PARTY_NOTICES.md) and [source provenance](EXTRACTION_AUDIT.md).
