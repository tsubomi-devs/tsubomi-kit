import SwiftUI
import TsubomiKitCore

/// 設定 › 一般 に置く「tsubomi のアプリをメニューバーで 1 つにまとめる」。
///
/// どのアプリで切り替えても、起動中のすべての tsubomi のアプリに伝わる。
/// アプリの設定画面の部品（SettingsCard の中の行）としてそのまま置ける。
public struct TsubomiMergeToggle: View {
    @ObservedObject private var coordinator: TsubomiMenuBarCoordinator

    public init(coordinator: TsubomiMenuBarCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Toggle(L("tsubomi のアプリをメニューバーで 1 つにまとめる"), isOn: Binding(
            get: { coordinator.preference == .merged },
            set: { coordinator.setPreference($0 ? .merged : .separate) }
        ))
        .help(L("tsubomi のアプリが 2 つ以上起動しているとき、メニューバーのアイコンを 🌸 1 つにします。機能はそれぞれのアプリのままです。"))
    }
}
