import AppKit
import SwiftUI

/// パネルの一番下：「⚙ 設定…」、版（ボタンにマウスを乗せている間はその名前）、右にアイコンのボタン。
///
/// Profilink・TouchRotator の下段と同じ見た目。新しいアプリはこれを使う。
/// アップデートの確認と終了のボタンは決まって入る。アプリごとのボタンは `extra` に足す。
public struct TsubomiPanelFooter<Extra: View>: View {
    private let appName: String
    private let status: String?
    private let showSettings: () -> Void
    private let checkForUpdates: (() -> Void)?
    private let extra: (Binding<String?>) -> Extra
    @State private var hint: String?

    /// - Parameters:
    ///   - appName: 「◯◯ を終了」に使う名前。
    ///   - status: 版の代わりに出す一言（試用の残り日数など）。nil なら「v1.2.3」。
    ///   - showSettings: 「設定…」を押したとき（パネルを閉じてから設定を開く）。
    ///   - checkForUpdates: アップデートの確認。nil ならボタンを出さない（自動更新を使えないビルド）。
    ///   - extra: アップデートの左に足すボタン。`TsubomiFooterButton` を、渡された hint とともに使う。
    public init(
        appName: String,
        status: String? = nil,
        showSettings: @escaping () -> Void,
        checkForUpdates: (() -> Void)?,
        @ViewBuilder extra: @escaping (Binding<String?>) -> Extra
    ) {
        self.appName = appName
        self.status = status
        self.showSettings = showSettings
        self.checkForUpdates = checkForUpdates
        self.extra = extra
    }

    /// 「v1.2.3」。試し用のビルド（通し番号が「1.2.3.7」のように版より長い）は「v1.2.3 テスト版 7」。
    /// 試し用か正式版かが、パネルを見ただけで分かるように。
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? short
        if build != short, build.hasPrefix(short + ".") {
            return "v\(short) " + TsubomiText.testBuild(String(build.dropFirst(short.count + 1)))
        }
        return "v" + short
    }

    public var body: some View {
        HStack(spacing: 4) {
            Button(action: showSettings) {
                Label(TsubomiText.settings, systemImage: "gearshape")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
            .padding(.trailing, 6)

            Text(verbatim: hint ?? status ?? version)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            extra($hint)
            if let checkForUpdates {
                TsubomiFooterButton(systemImage: "arrow.down.circle", title: TsubomiText.checkForUpdates, hint: $hint, action: checkForUpdates)
            }
            TsubomiFooterButton(systemImage: "power", title: TsubomiText.quit(appName), hint: $hint) {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}

public extension TsubomiPanelFooter where Extra == EmptyView {
    init(appName: String, status: String? = nil, showSettings: @escaping () -> Void, checkForUpdates: (() -> Void)?) {
        self.init(appName: appName, status: status, showSettings: showSettings, checkForUpdates: checkForUpdates) { _ in EmptyView() }
    }
}

/// 下段のアイコンボタン（28pt 四方、マウスを乗せると背景が付き、横の文字欄に名前が出る）。
/// Profilink・TouchRotator の FooterIconButton と同じもの。
public struct TsubomiFooterButton: View {
    private let systemImage: String
    private let title: String
    @Binding private var hint: String?
    private let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    /// `title` は訳したもの。
    public init(systemImage: String, title: String, hint: Binding<String?>, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.title = title
        _hint = hint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(hovering && isEnabled ? Color.primary.opacity(0.09) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
        .opacity(isEnabled ? 1 : 0.4)
        .help(title)
        .accessibilityLabel(title)
        .onHover { inside in
            hovering = inside
            hint = inside ? title : (hint == title ? nil : hint)
        }
    }
}
