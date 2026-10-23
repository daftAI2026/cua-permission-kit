# CUA Permission Kit

**English** | [简体中文](README.zh-CN.md)

<img src="Assets/DemoIcon.png" width="128" height="128" alt="CUA Permission Kit black-and-white flying saucer logo">

A Swift package for macOS permission onboarding, extracted from Incodex.
It provides device-control and screen-recording permission cards, guides users to
System Settings, and displays the permission state supplied by the host.
An independent community project, not affiliated with or endorsed by OpenAI.

[![Demo: drag both cards, return animations, and restart](Assets/Demo.gif)](Assets/Demo.mp4)

[Watch MP4](Assets/Demo.mp4) | 11.2s | 1080p

## Features

- Two cards: Device Control & Data Access, and Screen & System Audio Recording.
- Older systems show Accessibility and Screen Recording, depending on the OS version.
- Single-card integration by default; enable both cards through `permissions`.
- Original card tokens, draggable row, and spring animations preserved.
- Recording icon loaded from the system, with an SF Symbol fallback.
- Separate Demo controls using Radix color scales and centralized tokens.

## Quick Start

With Xcode command-line tools installed, run:

```sh
git clone https://github.com/daftAI2026/cua-permission-kit.git
cd cua-permission-kit
./script/build_and_run.sh
```

The Demo starts in simulation mode. Select **System Settings** to enter the real
Settings flow.
Integrate through Swift Package Manager, with a macOS 12+ deployment target and no
external dependencies. The deployment target does not mean runtime acceptance has
been completed on every macOS version.
See the [integration guide](INTEGRATION.md) for the complete example and API reference.

Verification commands:

```sh
swift test
CUA_RUN_WINDOW_TESTS=1 swift test # Requires an interactive macOS session
swift build -c release
```

## Safety

The library only displays state; the host checks actual permissions. Clicking or
dropping an application does not prove authorization.
The library does not reset TCC or elevate privileges. The Demo is built locally and
is not Apple-notarized.
Older macOS versions and multi-monitor placement remain unverified. See the
[acceptance record](EXTRACTION_AUDIT.md).

## When to show the permission cards

**We recommend completing authorization before the first main-app launch**, provided
an installer or launcher offers this flow. For embedded cards, show the permission
interface first. Start screen capture and automation only after the host confirms access.

Authorize the **final signed and installed app**, not its installer or helper.
Helper permissions do not authorize the main app. Re-signing or keeping multiple
copies with the same identifier can invalidate authorization.

Early authorization can reduce extra restarts, but cannot guarantee avoiding them.
Follow macOS requests to quit and reopen for screen recording and other permissions.

## Demo

- **Demo**: drag the application into the drop area to simulate completion of the current card, without changing system permissions.
- **System Settings**: open the corresponding Settings page; read-only probes check actual permissions. Simulation buttons do not prove authorization.
- **Restart**: reset the Demo, not system permissions.

Each card returns independently; completing both closes the guide. The recording
probe does not independently prove audio-only access.
`DemoSession.applicationName` defines the display name, which defaults to `"Demo"`.

## Opening a trusted, unnotarized Demo

This project does not distribute a Developer ID-signed, Apple-notarized Demo.
A local Apple Development certificate is used only for development signing, not
distribution notarization. Building from source does not require Apple Developer
Program membership. To explicitly use ad-hoc signing:

```sh
CUA_DEMO_SIGN_IDENTITY=- ./script/build_and_run.sh
```

Only if macOS blocks a **downloaded copy whose source you have verified and trust**,
use the following steps to remove the quarantine attribute and apply a new ad-hoc
signature to that Demo only.
This is not “removing the signature” and does not grant device-control or
screen-recording access. Do not run these steps for an app that opens normally,
an untrusted download, or an app whose original Developer ID signature must be preserved.

Quit the Demo first. Point `APP` to the exact copy you intend to run; the following
is the build script's output path:

```sh
APP="$HOME/Library/Caches/org.cuapermissionkit.demo/CUAPermissionDemo.app"
xattr -dr com.apple.quarantine "$APP"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
open "$APP"
```

If needed, do this before authorization: re-signing changes the app's identity and
may require granting access again.
There is no need for `sudo`, globally disabling Gatekeeper, removing the code
signature, or resetting TCC.
If Settings shows an old Demo entry as enabled but the probe still fails, first
confirm the running app's path. Remove and re-add only that Demo's old entry;
do not reset other apps' permissions.

## Contributing

Read [AGENTS.md](AGENTS.md) for project boundaries, development commands, and
acceptance requirements. Include regression tests for behavior changes. When filing
an issue, provide the macOS version, build commit, and Demo target.
Do not upload credentials or screenshots containing private content.

## License

Extracted from Incodex under the MIT license. See [LICENSE](LICENSE),
[third-party notices](THIRD_PARTY_NOTICES.md), and [source provenance](EXTRACTION_AUDIT.md).
