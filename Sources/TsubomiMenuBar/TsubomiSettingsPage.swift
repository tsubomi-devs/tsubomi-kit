import AppKit
import Combine
import SwiftUI
import TsubomiKitCore
import UniformTypeIdentifiers

/// 各アプリの設定に置く「tsubomi」のページ。どのアプリでも同じ中身。
///
/// - メニューバー：アイコンを 🌸 1 つにまとめるか（絵つきの 2 択）と、🌸 に入れるアプリ
/// - tsubomi のアプリ：入っているアプリの版・起動中か・開く。入っていないアプリは販売ページへ
///
/// 見た目は Profilink・TouchRotator の設定画面（SettingsChrome：システム設定と同じ寸法の
/// カード）と同じ値で描く。アプリの設定のサイドバーには、`TsubomiSettingsPage.title` と
/// `FlowerIcon.image`（白抜きにしてピンクの地に置く）で項目を足す。
public struct TsubomiSettingsPage: View {
    @ObservedObject private var coordinator: TsubomiMenuBarCoordinator
    /// 起動中かどうかなどを読み直すため、ページを開いたとき・アプリの起動や終了のたびに変える。
    @State private var refresh = 0

    /// サイドバーに出す名前。
    public static let title = "tsubomi"
    /// サイドバーの四角の色（tsubomi のロゴのピンク）。
    public static let tileColor = Color(red: 0.88, green: 0.27, blue: 0.54)

    public init(coordinator: TsubomiMenuBarCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KitMetrics.spacing) {
                menuBarCard
                appsCard
            }
            .padding(KitMetrics.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(refresh)
        }
        .onAppear { refresh += 1 }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in refresh += 1 }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in refresh += 1 }
    }

    // MARK: メニューバー

    private var isMerged: Bool { coordinator.preference == .merged }

    /// 🌸 に入れるかを選べるアプリ：一度起動したことがあり、いまも入っている tsubomi のアプリ。
    private var flowerApps: [KnownApp] {
        coordinator.knownApps
            .filter { $0.bundleID == coordinator.me.bundleID || installedURL($0.bundleID, fallbackPath: $0.appPath) != nil }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var menuBarCard: some View {
        KitCard(title: L("メニューバー"), footer: L("まとめると、メニューバーのアイコンが 🌸 1 つになり、押したあとパネルの上でアプリを切り替えられます。外したアプリは、自分のアイコンを出したままです。機能・ライセンスはそれぞれのアプリのままです。")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("表示のしかた"))
                HStack(spacing: 12) {
                    StyleChoice(
                        title: L("1 つにまとめる"),
                        isSelected: coordinator.preference == .merged,
                        action: { coordinator.setPreference(.merged) }
                    ) {
                        MiniMenuBar { Image(nsImage: FlowerIcon.image).renderingMode(.template).resizable().frame(width: 15, height: 15) }
                    }
                    StyleChoice(
                        title: L("アプリごとに表示"),
                        isSelected: coordinator.preference == .separate,
                        action: { coordinator.setPreference(.separate) }
                    ) {
                        MiniMenuBar {
                            ForEach(flowerApps.prefix(3), id: \.bundleID) { app in
                                AppIcon(path: installedURL(app.bundleID, fallbackPath: app.appPath)?.path ?? app.appPath)
                                    .frame(width: 15, height: 15)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)

            KitDivider()

            VStack(alignment: .leading, spacing: 2) {
                Text(L("🌸 に入れるアプリ"))
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                if flowerApps.count < 2 {
                    Text(L("一度起動した tsubomi のアプリが、ここに並びます。"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                }
                ForEach(flowerApps, id: \.bundleID) { app in
                    HStack(spacing: 10) {
                        AppIcon(path: installedURL(app.bundleID, fallbackPath: app.appPath)?.path ?? app.appPath)
                            .frame(width: 22, height: 22)
                        Text(verbatim: app.name)
                        if app.bundleID == coordinator.me.bundleID {
                            Text(L("（このアプリ）")).foregroundColor(.secondary)
                        }
                        Spacer(minLength: 12)
                        Toggle("", isOn: Binding(
                            get: { !coordinator.excludedApps.contains(app.bundleID) },
                            set: { coordinator.setIncluded($0, bundleID: app.bundleID) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel(app.name)
                    }
                    .frame(minHeight: 32)
                }
                Spacer().frame(height: 6)
            }
            .disabled(!isMerged)
            .opacity(isMerged ? 1 : 0.45)
        }
    }

    // MARK: tsubomi のアプリ

    private struct Row: Identifiable {
        var bundleID: String
        var name: String
        var tagline: String?
        var page: URL?
        var iconURL: URL?
        var installedURL: URL?
        var id: String { bundleID }
    }

    private var rows: [Row] {
        var rows = TsubomiCatalog.apps.map { app in
            Row(
                bundleID: app.bundleID,
                name: app.name,
                tagline: app.tagline.current,
                page: URL(string: app.page.current),
                iconURL: app.iconURL,
                installedURL: installedURL(app.bundleID, fallbackPath: nil)
            )
        }
        // 一覧に載っていなくても、一度起動した tsubomi のアプリは並べる（この版より新しいアプリ）。
        for known in coordinator.knownApps where !rows.contains(where: { $0.bundleID == known.bundleID }) {
            guard let url = installedURL(known.bundleID, fallbackPath: known.appPath) else { continue }
            rows.append(Row(bundleID: known.bundleID, name: known.name, tagline: nil, page: nil, iconURL: nil, installedURL: url))
        }
        // 入っているものを先に、それぞれ名前順。
        return rows.sorted {
            if ($0.installedURL != nil) != ($1.installedURL != nil) { return $0.installedURL != nil }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var appsCard: some View {
        KitCard(title: L("tsubomi のアプリ"), footer: L("tsubomi のほかのアプリも、このアプリと同じ作りで、メニューバーにまとめられます。")) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { KitDivider() }
                appRow(row)
            }
        }
    }

    private func appRow(_ row: Row) -> some View {
        HStack(spacing: 12) {
            Group {
                if let url = row.installedURL {
                    AppIcon(path: url.path)
                } else if let iconURL = row.iconURL {
                    RemoteIcon(url: iconURL)
                } else {
                    AppIcon(path: "")
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: row.name).font(.body.weight(.semibold))
                    if let version = row.installedURL.flatMap(Self.version(of:)) {
                        Text(verbatim: "v" + version).font(.caption).foregroundColor(.secondary)
                    }
                }
                if let tagline = row.tagline {
                    Text(tagline)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            trailing(for: row)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func trailing(for row: Row) -> some View {
        if row.bundleID == coordinator.me.bundleID {
            StatusLabel(text: L("このアプリ"), color: .secondary)
        } else if let url = row.installedURL {
            if coordinator.isRunning(row.bundleID) {
                StatusLabel(text: L("起動中"), color: .green)
            } else {
                Button(L("開く")) {
                    let configuration = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
                }
            }
        } else if let page = row.page {
            Button(L("詳しく見る")) { NSWorkspace.shared.open(page) }
                .buttonStyle(.borderedProminent)
        } else {
            StatusLabel(text: L("入っていません"), color: .secondary)
        }
    }

    // MARK: 調べもの

    private func installedURL(_ bundleID: String, fallbackPath: String?) -> URL? {
        if bundleID == coordinator.me.bundleID { return Bundle.main.bundleURL }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) { return url }
        if let path = fallbackPath, FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        return nil
    }

    private static func version(of appURL: URL) -> String? {
        Bundle(url: appURL)?.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - 部品

/// 設定のカード（Profilink・TouchRotator の SettingsChrome と同じ寸法：角丸 10、余白 20、
/// 行の左右 10、塗りは黒か白の 7/255）。
private enum KitMetrics {
    /// カードとページの端のあいだ。
    static let inset: CGFloat = 20
    /// カードとカードのあいだ。
    static let spacing: CGFloat = 20
}

private struct KitCard<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(7.0 / 255.0))
            )
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// カードの中の区切り線（カードの左右いっぱい）。
private struct KitDivider: View {
    var body: some View {
        Divider().padding(.horizontal, -10)
    }
}

/// 「表示のしかた」の選択肢 1 つ：小さなメニューバーの絵と名前。選ぶと青い枠。
private struct StyleChoice<Illustration: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var illustration: Illustration

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                illustration
                HStack(spacing: 5) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                    Text(title)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 「表示のしかた」の絵：画面の上のメニューバーの右端に、アイコンが並んでいるところ。
private struct MiniMenuBar<Icons: View>: View {
    @ViewBuilder var icons: Icons

    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(Color.primary.opacity(0.18)).frame(width: 22, height: 5)
            Capsule().fill(Color.primary.opacity(0.12)).frame(width: 16, height: 5)
            Spacer(minLength: 6)
            icons
            Text(verbatim: "9:41")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.primary.opacity(0.7))
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

/// 入っているアプリのアイコン。
private struct AppIcon: View {
    let path: String

    var body: some View {
        Image(nsImage: path.isEmpty
            ? NSWorkspace.shared.icon(for: .applicationBundle)
            : NSWorkspace.shared.icon(forFile: path))
            .resizable()
            .interpolation(.high)
    }
}

/// 入っていないアプリのアイコン（販売ページに置いてある画像）。読めなければ汎用のアイコン。
private struct RemoteIcon: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().interpolation(.high)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(for: .applicationBundle))
                    .resizable()
                    .opacity(0.5)
            }
        }
    }
}

/// 右端の短い状態（このアプリ・起動中など）。
private struct StatusLabel: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            if color == .green {
                Circle().fill(color).frame(width: 7, height: 7)
            }
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}
