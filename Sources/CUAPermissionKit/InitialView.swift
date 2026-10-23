// [INPUT]: 依赖 AppKit、SwiftUI 与包内视图协作。
// [OUTPUT]: 提供初始授权卡与设置占位视图。
// [POS]: 授权向导表现层；不读写系统授权数据库。
// [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
import AppKit
import SwiftUI
@MainActor
private final class PermissionInitialState: ObservableObject {
    @Published var title = ""
    @Published var body = ""
    @Published var permissionTitle = ""
    @Published var permissionDescription = ""
    @Published var allow = ""
    var completedLabel = "Allowed"
    @Published var skip = ""
    @Published var completeInSettings = ""
    @Published var appIcon: NSImage?
    @Published var permissionIcon: NSImage?
    @Published var allowEnabled = true
    @Published var settingsPlaceholder = false
    @Published var placeholderHovered = false
    @Published var layoutDirection: LayoutDirection = .leftToRight
    var onAllow: (() -> Void)?
    @Published var selectedIndex = 0
    var completed = false
    var isDefaultAction = true
    weak var actionTarget: NSObject?

    func configure(
        copy: NSDictionary,
        appIcon: NSImage?,
        permissionIcon: NSImage?,
        actionTarget: NSObject?,
    ) {
        title = permissionCopyString(copy, "title")
        body = permissionCopyString(copy, "body")
        permissionTitle = permissionCopyString(copy, "permissionTitle")
        permissionDescription = permissionCopyString(copy, "permissionDescription")
        allow = permissionCopyString(copy, "repair")
        let granted = permissionCopyString(copy, "granted")
        completedLabel = granted.isEmpty ? "Allowed" : granted
        skip = permissionCopyString(copy, "later")
        completeInSettings = permissionCopyString(copy, "completeInSettings")
        self.appIcon = appIcon
        self.permissionIcon = permissionIcon
        self.actionTarget = actionTarget
        layoutDirection = permissionCopyString(copy, "layoutDirection") == "rightToLeft" ? .rightToLeft : .leftToRight
        allowEnabled = true
        settingsPlaceholder = false
        placeholderHovered = false
    }

    func setContent(
        title: String,
        body: String,
        allowEnabled: Bool,
        settingsPlaceholder: Bool,
    ) {
        self.title = title
        self.body = body
        self.allowEnabled = allowEnabled
        self.settingsPlaceholder = settingsPlaceholder
        // State transitions must not reuse a previous placeholder's hover.
        // A later genuine pointer entry may establish fresh hover normally.
        placeholderHovered = false
    }

    func send(_ selector: String) {
        precondition(Thread.isMainThread, "Permission actions must run on the main thread")
        if selector == "allow:", let onAllow { onAllow(); return }
        guard let actionTarget else { return }
        _ = NSApp.sendAction(Selector(selector), to: actionTarget, from: nil)
    }
}

struct PermissionEmbeddedView: NSViewRepresentable {
    let view: NSView
    let size: CGSize

    func makeNSView(context: Context) -> NSView { view }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Do not touch isHidden here: Runtime deliberately hides the stable host
        // while taking permission-card snapshots and restores it independently.
        nsView.setFrameSize(size)
    }
}

private struct PermissionAllowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlActiveState) private var controlActiveState

    func makeBody(configuration: Configuration) -> some View {
        PermissionAllowButtonFace(
            label: configuration.label,
            isEnabled: isEnabled,
            isActive: controlActiveState == .key,
            isPressed: configuration.isPressed
        )
    }
}

private struct PermissionAllowButtonFace<Label: View>: View {
    let label: Label
    let isEnabled: Bool
    let isActive: Bool
    let isPressed: Bool

    private var foreground: Color {
        guard isEnabled else { return Color(nsColor: .disabledControlTextColor) }
        return isActive ? .white : Color(nsColor: .controlTextColor)
    }

    private var background: Color {
        guard isEnabled else { return Color(nsColor: .controlColor) }
        guard !isActive else { return .accentColor }
        if #available(macOS 14.0, *) { return Color(nsColor: .systemFill) }
        return Color.primary.opacity(0.08)
    }

    var body: some View {
        label
            // 4pt was the measured label adjustment under the automatic
            // style; replace its lost 8pt-per-side system inset explicitly.
            .padding(.horizontal, 12)
            .frame(height: 24)
            .foregroundStyle(foreground)
            .background {
                Capsule(style: .continuous)
                    .fill(background)
                    // Original Allow has no visible hover treatment. Its
                    // pressed fill darkens in place, without another surface.
                    .brightness(isPressed ? -0.115 : 0)
            }
            .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

private struct PermissionCardRoot: View {
    @ObservedObject var state: PermissionInitialState
    @Environment(\.colorScheme) private var colorScheme

    var foreground: some View {
        // Original PermissionRow: zero stack spacing, independently padded
        // 64pt icon, then a flexible leading text column and trailing control.
        HStack(spacing: 0) {
            Group {
                if let image = state.permissionIcon {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                } else {
                    Color.clear.frame(width: 64, height: 64)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 12.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.permissionTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    // Preserve the measured CUA glyph origin (84.5, 20.5).
                    // Current SwiftUI places this glyph 1pt lower despite the
                    // same 16pt font and 2pt stack spacing; do not move the body.
                    .offset(y: -1)
                Text(state.permissionDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { state.send("allow:") } label: {
                Text(state.allow)
            }
                .buttonStyle(PermissionAllowButtonStyle())
                .keyboardShortcutIfDefault(state.isDefaultAction)
                .clipShape(Capsule(style: .continuous))
                .frame(minWidth: 62)
                .offset(x: state.layoutDirection == .rightToLeft ? -4 : 4)
                .disabled(!state.allowEnabled)
        }
        .padding(.trailing, 20)
        .frame(width: 518, height: 80)
    }

    var body: some View {
        foreground
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.09), radius: 25, x: 0, y: 5)
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 0)
        .environment(\.layoutDirection, state.layoutDirection)
    }
}

private struct PermissionPlaceholderLabel<Label: View>: View {
    let label: Label
    let pressed: Bool
    @ObservedObject var state: PermissionInitialState

    var body: some View {
        label
            .frame(maxWidth: .infinity, minHeight: 80)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.primary.opacity(state.placeholderHovered ? 0.018 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        Color.primary.opacity(pressed ? 0.22 : state.placeholderHovered ? 0.18 : 0.16),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 6]),
                    )
            }
            .scaleEffect(pressed ? 0.99 : 1)
            .opacity(pressed ? 0.88 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onHover { state.placeholderHovered = $0 }
    }
}

private func permissionPlaceholderText(_ value: String) -> Text {
    let attributed = NSAttributedString(
        string: value,
        attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .kern: 0.7,
        ],
    )
    return Text(AttributedString(attributed))
}

private struct PermissionPlaceholderButtonStyle: ButtonStyle {
    let state: PermissionInitialState

    func makeBody(configuration: Configuration) -> some View {
        PermissionPlaceholderLabel(
            label: configuration.label,
            pressed: configuration.isPressed,
            state: state,
        )
    }
}

private struct PermissionInitialRoot: View {
    @ObservedObject var state: PermissionInitialState
    let cardHosts: [NSView]

    var body: some View {
        VStack(spacing: 0) {
            if let image = state.appIcon {
                Image(nsImage: image)
                    .interpolation(.high)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .padding(.top, 28)
            } else {
                Color.clear.frame(width: 64, height: 64).padding(.top, 28)
            }

            Text(state.title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 560)
                .padding(.top, 20)
                .offset(y: -11)

            Text(state.body)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 518)
                .padding(.top, 3)

            VStack(spacing: 12) {
                ForEach(cardHosts.indices, id: \.self) { index in
                    ZStack {
                        PermissionEmbeddedView(view: cardHosts[index], size: CGSize(width: 518, height: 80))
                        if state.settingsPlaceholder && state.selectedIndex == index {
                            Button { state.send("resumeSettings:") } label: {
                                permissionPlaceholderText(state.completeInSettings).opacity(0.86)
                            }
                            .buttonStyle(PermissionPlaceholderButtonStyle(state: state))
                        }
                    }
                    .frame(width: 518, height: 80)
                }
            }
            .padding(.top, 21)
        }
        .frame(width: 600)
        .offset(y: -9)
        .padding(.bottom, 32)
        .background(.regularMaterial)
        .overlay(alignment: .bottomTrailing) {
            if !state.settingsPlaceholder {
                Button(state.skip) { state.send("skip:") }
                    .buttonStyle(.plain)
                    .frame(height: 41, alignment: .center)
                    .padding(.trailing, 57)
            }
        }
        .environment(\.layoutDirection, state.layoutDirection)
    }
}

@MainActor
@objc(PCKPermissionInitialView)
public final class PCKPermissionInitialView: NSView {
    private let state: PermissionInitialState
    private let host: NSHostingView<PermissionInitialRoot>
    private var cardHosts: [NSHostingView<PermissionCardRoot>]
    private var cardStates: [PermissionInitialState]
    private var cardHost: NSHostingView<PermissionCardRoot> { cardHosts[state.selectedIndex] }

    @objc public var permissionCardView: NSView { cardHost }

    @objc(snapshotPermissionCardWithScale:)
    public func snapshotPermissionCard(scale: CGFloat) -> NSImage? {
        precondition(Thread.isMainThread, "Permission snapshots must run on the main thread")
        let colorScheme: ColorScheme = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .dark : .light
        let foreground = PermissionCardRoot(state: cardStates[state.selectedIndex]).foreground
            .environment(\.layoutDirection, state.layoutDirection)
            .environment(\.colorScheme, colorScheme)
        return permissionForegroundSnapshot(
            content: foreground, size: cardHost.bounds.size, scale: scale,
            appearance: effectiveAppearance, useHostingView: true
        )
    }

    @objc public var preferredContentSize: NSSize {
        precondition(Thread.isMainThread, "Permission layout must run on the main thread")
        let measured = host.fittingSize
        return NSSize(width: 600, height: measured.height)
    }

    public override var isFlipped: Bool { true }

    public override init(frame frameRect: NSRect) {
        precondition(Thread.isMainThread, "Permission views must be created on the main thread")
        let state = PermissionInitialState()
        let cardHost = NSHostingView(rootView: PermissionCardRoot(state: state))
        self.state = state
        self.cardHosts = [cardHost]
        self.cardStates = [state]
        host = NSHostingView(rootView: PermissionInitialRoot(state: state, cardHosts: [cardHost]))
        super.init(frame: frameRect)
        cardHost.frame = NSRect(x: 0, y: 0, width: 518, height: 80)
        cardHost.autoresizingMask = [.width, .height]
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    public override func layout() {
        super.layout()
        host.frame = bounds
    }

    @objc(configureWithCopy:appIcon:permissionIcon:actionTarget:)
    public func configure(
        copy: NSDictionary,
        appIcon: NSImage?,
        permissionIcon: NSImage?,
        actionTarget: NSObject?,
    ) {
        precondition(Thread.isMainThread, "Permission configuration must run on the main thread")
        state.configure(copy: copy, appIcon: appIcon, permissionIcon: permissionIcon, actionTarget: actionTarget)
    }

    func configureCards(copies: [NSDictionary], icons: [NSImage?], onAllow: @escaping (Int) -> Void) {
        cardStates = copies.enumerated().map { index, copy in
            let row = PermissionInitialState()
            row.configure(copy: copy, appIcon: nil, permissionIcon: icons[index], actionTarget: nil)
            row.isDefaultAction = index == 0
            row.onAllow = { onAllow(index) }
            return row
        }
        cardHosts = cardStates.map { row in
            let view = NSHostingView(rootView: PermissionCardRoot(state: row))
            view.frame = NSRect(x: 0, y: 0, width: 518, height: 80)
            return view
        }
        state.selectedIndex = 0
        host.rootView = PermissionInitialRoot(state: state, cardHosts: cardHosts)
    }

    func selectCard(at index: Int) { state.selectedIndex = index }

    func markCompleted(_ indexes: Set<Int>) {
        let next = cardStates.indices.first { !indexes.contains($0) }
        for (index, row) in cardStates.enumerated() {
            row.isDefaultAction = index == next
            row.completed = indexes.contains(index)
            row.allowEnabled = !row.completed
            if row.completed { row.allow = row.completedLabel }
        }
    }

    @objc(setContentWithTitle:body:allowEnabled:settingsPlaceholder:)
    public func setContent(
        title: String,
        body: String,
        allowEnabled: Bool,
        settingsPlaceholder: Bool,
    ) {
        precondition(Thread.isMainThread, "Permission content must run on the main thread")
        state.setContent(title: title, body: body, allowEnabled: allowEnabled, settingsPlaceholder: settingsPlaceholder)
        for row in cardStates { row.allowEnabled = allowEnabled && !row.completed }
        // The Runtime measures immediately after this selector returns. Reassign
        // the same root value synchronously so a @Published update cannot leave
        // fittingSize one body revision behind; cardHost remains the stable
        // embedded NSHostingView used by the snapshot/placeholder bridge.
        host.rootView = PermissionInitialRoot(state: state, cardHosts: cardHosts)
        host.needsLayout = true
        host.layoutSubtreeIfNeeded()
    }
}
