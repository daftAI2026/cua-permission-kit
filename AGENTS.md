# CUA Permission Kit Agent Guide

## Project

CUA Permission Kit is a dependency-free Swift package for macOS permission onboarding.
It extracts Incodex's native card UI and adds two independent permission kinds.
It is a community project, not an OpenAI product or authorization service.

Read [CLAUDE.md](CLAUDE.md) for the project map and the affected module's
`CLAUDE.md` before editing. This file defines contributor rules; module maps describe
source responsibilities. Keep these documents consistent, without duplicating them.

## Product boundary

- Preserve the extracted card layout, spacing, semantic colors and spring behavior.
- Keep application URL, display name, icons, copy and handoff target configurable.
- Keep dependencies one-way: `DemoController → DemoSession → CUAPermissionKit`.
- Keep Demo controls, tokens, icon assets, simulated results and permission probes outside the library.
- Use `DemoSession.applicationName` for the Demo display name. Do not confuse it with the bundle ID or dragged application URL.
- The host checks authorization. The library only presents the supplied state.
- Do not turn the package into an installer, permission broker or background service.

## Repository map

| Path | Responsibility |
| --- | --- |
| `Sources/CUAPermissionKit/` | Public configuration, presenter, cards, tracking and transitions |
| `Examples/CUAPermissionDemo/` | Standalone host, target adapter and read-only probes |
| `Tests/CUAPermissionKitTests/` | Configuration, source parity and window lifecycle tests |
| `Tests/CUAPermissionDemoTests/` | Demo identity, icon and simulation isolation tests |
| `Assets/` | Demo Icon Composer source and PNG/ICNS exports |
| `script/build_and_run.sh` | Build, sign and launch the cache-directory Demo |
| `.github/workflows/ci.yml` | macOS build, unit tests and Release compilation |
| `EXTRACTION_AUDIT.md` | Incodex baseline, intentional differences and verification limits |

## Safety contracts

- Opening Settings or accepting a file drop does not prove authorization. Send `.granted` only after the host's real check succeeds.
- In Demo-target mode, file drops simulate completion. Never report that result as system authorization.
- Cancel checks when closing or changing cards. Do not apply a previous card's result to the active card.
- Do not request permissions on mouse-down. Read-only probes must not trigger authorization prompts.
- Do not reset TCC, elevate privileges, disable Gatekeeper globally or modify another app's permissions or signature.
- Grant access to the final installed host, not a helper. Keep signing identity and bundle location stable during acceptance.
- The run script signs only the Demo. It rejects the legacy `dist` bundle instead of deleting it automatically.
- Leave password and Touch ID entry to the user. Real permission changes require explicit authorization.

## Development

Use the existing SwiftUI/AppKit implementation. Add a failing regression test before
changing behavior. Keep fixes scoped and preserve unrelated working-tree changes.
Do not modify the Incodex checkout while working on this extracted package.

```sh
swift build
swift test
swift build -c release
CUA_RUN_WINDOW_TESTS=1 swift test
./script/build_and_run.sh
```

The last two commands require an interactive macOS session and can open windows.
The run script stages the Demo under
`~/Library/Caches/org.cuapermissionkit.demo/CUAPermissionDemo.app`.
It uses the unique local Apple Development identity when available; set
`CUA_DEMO_SIGN_IDENTITY=-` for ad-hoc signing. Rebuilding can require reauthorization.

## Verification

- Code changes: run build, tests and Release compilation. Read exit status and suite summaries; report skipped tests separately.
- UI changes: also run opt-in window tests and inspect the actual Demo. Verify both cards, return animation, completion and Restart.
- Handoff changes: verify the selected destination, actual dragged URL and activation from another foreground app. Simulation does not prove Settings acceptance.
- Visual changes: retain the eight extraction-parity checks. Source parity does not prove pixel parity or behavior on every OS.
- Documentation changes: check relative links, examples and English/Chinese consistency. Keep the logo in both README files.
- After a push, verify CI for the exact pushed commit. Queued, cancelled or running checks are not success.
- Older macOS and multi-monitor acceptance are non-blocking follow-ups for the source preview, not verified compatibility claims.

## Documentation and delivery

Keep source files under 800 lines. Update affected INPUT/OUTPUT/POS contracts and
module maps when dependencies, exports or responsibilities change. Check the root
map when adding top-level files or modules.

Keep README prose technical and concise. Recommend onboarding before the main app
starts protected features; do not promise that macOS will never require a restart.
The English README is the full API reference; the Chinese README links to it.

A pushed source commit is not a packaged release. Do not create tags or GitHub
Releases without explicit maintainer confirmation. Do not claim Developer ID signing
or Apple notarization for the locally built Demo. Never publish local credentials,
certificate details or private test captures.
