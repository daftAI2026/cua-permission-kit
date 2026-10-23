# CUA Permission Kit

**English** | [简体中文](README.zh-CN.md)

<img src="Assets/DemoIcon.png" width="128" height="128" alt="CUA Permission Kit black-and-white flying saucer logo">

A Swift package for macOS permission onboarding, extracted from Incodex. It renders
device-control and screen-recording cards, guides users to System Settings, and
displays the permission state supplied by the host application.

**Independent community project. Not affiliated with or endorsed by OpenAI.**
CUA describes the computer-use workflow; this package does not ship OpenAI binaries, icons, or an authorization service.

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

## When to show the guide

**Prefer completing permission onboarding before the first main-app launch**,
when an installer or launcher provides that flow. For an embedded guide, start only
the onboarding UI and confirm access before starting screen capture or automation.
This can reduce an extra restart after the user has begun work.

If your installer or launcher offers onboarding before the first main-app launch,
add the **final installed app bundle** to System Settings, not the installer or helper.
If the guide runs inside your app, launch only the onboarding UI first; start protected
features after the actual host process confirms access. A helper's permissions are
not proof that the main app is authorized.

This can reduce an extra relaunch, but cannot guarantee a restart-free flow.
Honor any macOS request to quit and reopen, especially for screen recording.
Finish signing and installing the app before granting access; changing its identity
or keeping multiple bundles with the same ID can invalidate the authorization.

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

## Demo and verification

```sh
./script/build_and_run.sh
swift test
CUA_RUN_WINDOW_TESTS=1 swift test # interactive macOS session required
```

The Demo uses `DemoSession.applicationName` as its display-name variable (default: `"Demo"`).
Changing this value updates the card and its generated instructions, not the bundle ID
or the application URL used for dragging.

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

Local verification on 2026-10-23, macOS 27.0.1 arm64: both real file drags into the Demo, independent
completion, return animation and restart passed; 21 tests passed including seven
opt-in window tests. Both real permission probes also passed after removing the stale
Demo entry and legacy bundle; a development-signed rebuild retained access. This does
not certify old OS versions, multi-monitor placement, or every authorization transition.

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
not a Developer ID-signed or notarized downloadable application. A first source preview must pass
release compilation, the external README integration build, CI and the opt-in window
suite. Older macOS versions and multi-monitor placement remain unverified; these
follow-up checks do not block the current source preview. The macOS 12 deployment
target is a build setting, not evidence of runtime compatibility on every supported OS.
The automated gates do not certify every system authorization transition.
Tags and GitHub Releases require maintainer confirmation. No version tag is published yet.

## Library and Demo boundary

Dependencies flow one way: `DemoController → DemoSession → CUAPermissionKit`.
The controller composes Demo controls; the session owns target adaptation,
simulated results, and read-only probes. Demo tokens, icons, and drop targets
remain outside the library. Library and Demo tests use separate targets.

[Source comparison and outstanding checks](EXTRACTION_AUDIT.md).

### Demo build identity

Trash the legacy `dist/CUAPermissionDemo.app` before using the Run script.
Duplicate bundle IDs can make Settings reopen the older build. The script signs
only the Demo bundle, using the unique local Apple Development identity when
available. Set `CUA_DEMO_SIGN_IDENTITY` when several identities exist. Without
a development identity it uses ad-hoc signing, which may require reauthorization
after rebuilding. The script never resets permission records.

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
