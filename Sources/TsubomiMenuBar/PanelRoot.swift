import AppKit
import SwiftUI
import TsubomiKitCore

/// パネルの寸法。Profilink・TouchRotator のパネルと同じ値。
public enum PanelMetrics {
    /// パネルの幅。
    public static let width: CGFloat = 320
    /// パネルの角丸。
    public static let cornerRadius: CGFloat = 26
    /// パネルの内側の余白。
    public static let padding: CGFloat = 12
    /// パネルの中のカードの角丸。
    public static let cardCornerRadius: CGFloat = 14
    /// カードの塗り。
    public static var cardFill: Color { Color(nsColor: .controlBackgroundColor).opacity(0.72) }
}

/// パネル全体：ガラスの背景の上に、切り替え・「まとめますか？」・アプリの中身を縦に並べる。
///
/// 型を名前で持つ（AnyView で包まない）。AnyView にすると状態が変わるたびに木全体が
/// 作り直され、AppKit の制約の片付けがたまって落ちたことがある（TouchRotator）。
struct PanelRoot<Content: View>: View {
    @ObservedObject var coordinator: TsubomiMenuBarCoordinator
    let actions: PanelActions
    let content: Content

    var body: some View {
        TsubomiPanelChrome {
            VStack(alignment: .leading, spacing: 10) {
                if coordinator.role.isMerged {
                    SwitcherStrip(
                        items: coordinator.switcherItems,
                        current: coordinator.me.bundleID,
                        select: { actions.switchHandler?($0) }
                    )
                }
                if coordinator.asksToMerge {
                    MergePrompt(
                        otherNames: coordinator.roster.mergeCandidates
                            .filter { $0.bundleID != coordinator.me.bundleID }
                            .map(\.name),
                        answer: { coordinator.setPreference($0) }
                    )
                }
                content
            }
        }
    }
}

/// パネルの外側：ガラスの背景・角丸 26・幅 320・余白 12。
///
/// TsubomiMenuBar のパネルはこれで包まれる。撮影モードなど、メニューバーを通さずに
/// パネルの中身だけを窓に出すときも、これで包めば同じ見た目になる。
public struct TsubomiPanelChrome<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(PanelMetrics.padding)
            .frame(width: PanelMetrics.width)
            .background(PanelGlassBackground())
            .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

/// まとめているときにパネルの上に出す、アプリの切り替え。
struct SwitcherStrip: View {
    let items: [SwitcherItem]
    let current: String
    let select: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                SwitcherButton(item: item, isCurrent: item.bundleID == current) {
                    // いま開いているアプリを押しても何もしない。
                    if item.bundleID != current { select(item.bundleID) }
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius + 2, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("アプリを選ぶ"))
    }
}

private struct SwitcherButton: View {
    let item: SwitcherItem
    let isCurrent: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.appPath))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)
                    .opacity(item.isRunning ? 1 : 0.45)
                Text(verbatim: item.name)
                    .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(item.isRunning ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius, style: .continuous)
                    .fill(background)
                    .shadow(color: isCurrent ? .black.opacity(0.12) : .clear, radius: 1.5, y: 1)
            )
            .contentShape(Rectangle())
        }
        // 押せなくする（disabled）と macOS が灰色に描き、いま開いているアプリのほうが
        // 薄く見えてしまう。押しても何も起きないだけにして、見た目ははっきり残す。
        .buttonStyle(.plain)
        .onHover { hovering = $0 && !isCurrent }
        .help(item.isRunning ? item.name : L("%@ を起動して開く", item.name))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var background: Color {
        if isCurrent { return PanelMetrics.cardFill }
        return hovering ? Color.primary.opacity(0.06) : .clear
    }
}

/// tsubomi のアプリが 2 つ以上起動したとき、一度だけ出す「まとめますか？」。
struct MergePrompt: View {
    let otherNames: [String]
    let answer: (MergePreference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                FlowerBadge()
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("メニューバーのアイコンをまとめますか？"))
                        .font(.callout.weight(.semibold))
                    Text(L("%@ も起動しています。tsubomi のアプリのアイコンを 1 つにまとめ、押したあとに上で切り替えられます。設定 › tsubomi でいつでも変えられます。", otherNames.joined(separator: L("、"))))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(L("別々のまま")) { answer(.separate) }
                    .controlSize(.small)
                Button(L("まとめる")) { answer(.merged) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        )
    }
}

/// 「まとめますか？」の横に出す、色つきの 🌸。
private struct FlowerBadge: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(red: 0.93, green: 0.42, blue: 0.66), Color(red: 0.86, green: 0.18, blue: 0.48)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                Image(nsImage: FlowerIcon.image)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(.white)
                    .padding(3)
            )
    }
}

/// パネルのガラスの背景（Profilink・TouchRotator と同じ）。角丸は画像のマスクで切り抜く。
struct PanelGlassBackground: NSViewRepresentable {
    private static let cornerMask: NSImage = {
        let radius = PanelMetrics.cornerRadius
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }()

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.cornerMask
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
