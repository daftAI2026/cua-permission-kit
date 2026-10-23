# Integration

CUA Permission Kit integration and API reference.
Back to [English README](README.md) or [中文说明](README.zh-CN.md).

## Add the library

Add `.package(path: "../cua-permission-kit")` to your package dependencies and
`.product(name: "CUAPermissionKit", package: "cua-permission-kit")` to your target dependencies.
No remote release or version tag is required for local integration.

## Present the guide

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

