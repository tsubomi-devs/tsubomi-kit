import Foundation

/// この部品が話す言語。アプリ自身が選んだ言語（Bundle.main の preferredLocalizations）に合わせる。
/// 日本語・中国語（簡体字。TouchRotator が対応している）以外は英語。
enum KitLanguage {
    case ja, en, zh
}

var currentLanguage: KitLanguage {
    let language = Bundle.main.preferredLocalizations.first ?? "ja"
    if language.hasPrefix("ja") { return .ja }
    if language.hasPrefix("zh") { return .zh }
    return .en
}

/// この部品の文言。キーは日本語の原文（Profilink・TouchRotator と同じ方式）。
///
/// 訳はファイル（.lproj）ではなく、ここに持つ。SwiftPM のリソースは別のバンドルになり、
/// アプリの .app を Makefile で組み立てるときに入れ忘れると、Bundle.module が見つからずに
/// 起動時に落ちる。コードの中に持てば、何もコピーしなくても動く。
func L(_ key: String) -> String {
    switch currentLanguage {
    case .ja: return key
    case .zh: return chinese[key] ?? english[key] ?? key
    case .en: return english[key] ?? key
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}

private let english: [String: String] = [
    // パネルの下段
    "設定…": "Settings…",
    "アップデートを確認": "Check for Updates",
    "%@ を終了": "Quit %@",
    "テスト版 %@": "test build %@",
    "tsubomi のアプリ": "tsubomi apps",
    "アプリを選ぶ": "Choose an app",
    "%@ を起動して開く": "Open %@",
    "メニューバーのアイコンをまとめますか？": "Combine the menu bar icons?",
    "%@ も起動しています。tsubomi のアプリのアイコンを 1 つにまとめ、押したあとに上で切り替えられます。設定 › tsubomi でいつでも変えられます。":
        "%@ is also running. Show one icon for all tsubomi apps and switch between them at the top of the panel. You can change this any time in Settings › tsubomi.",
    "、": ", ",
    "別々のまま": "Keep Separate",
    "まとめる": "Combine",
    "tsubomi のアプリをメニューバーで 1 つにまとめる": "Combine tsubomi apps into one menu bar icon",
    "tsubomi のアプリが 2 つ以上起動しているとき、メニューバーのアイコンを 🌸 1 つにします。機能はそれぞれのアプリのままです。":
        "When two or more tsubomi apps are running, show a single 🌸 icon in the menu bar. Each app keeps all of its own features.",
    // 設定 › tsubomi
    "メニューバー": "Menu Bar",
    "表示のしかた": "Show icons",
    "1 つにまとめる": "Combined",
    "アプリごとに表示": "One per app",
    "🌸 に入れるアプリ": "Apps in 🌸",
    "（このアプリ）": "(this app)",
    "まとめると、メニューバーのアイコンが 🌸 1 つになり、押したあとパネルの上でアプリを切り替えられます。外したアプリは、自分のアイコンを出したままです。機能・ライセンスはそれぞれのアプリのままです。":
        "Combined shows a single 🌸 in the menu bar; click it and switch apps at the top of the panel. An app taken out keeps its own icon. Each app keeps its own features and license.",
    "一度起動した tsubomi のアプリが、ここに並びます。": "tsubomi apps appear here once they have been opened.",
    "このアプリ": "This app",
    "起動中": "Running",
    "開く": "Open",
    "詳しく見る": "Learn More",
    "入っていません": "Not installed",
    "tsubomi のほかのアプリも、このアプリと同じ作りで、メニューバーにまとめられます。": "Other tsubomi apps are made the same way and can share the menu bar with this one.",
]

private let chinese: [String: String] = [
    "設定…": "设置…",
    "アップデートを確認": "检查更新",
    "%@ を終了": "退出 %@",
    "テスト版 %@": "测试版 %@",
    "tsubomi のアプリ": "tsubomi 应用",
    "アプリを選ぶ": "选择应用",
    "%@ を起動して開く": "打开 %@",
    "メニューバーのアイコンをまとめますか？": "要合并菜单栏图标吗？",
    "%@ も起動しています。tsubomi のアプリのアイコンを 1 つにまとめ、押したあとに上で切り替えられます。設定 › tsubomi でいつでも変えられます。":
        "%@ 也在运行。可将 tsubomi 应用的图标合并为一个，点按后在面板顶部切换。随时可在“设置 › tsubomi”中更改。",
    "、": "、",
    "別々のまま": "保持分开",
    "まとめる": "合并",
    "tsubomi のアプリをメニューバーで 1 つにまとめる": "将 tsubomi 应用合并为一个菜单栏图标",
    "tsubomi のアプリが 2 つ以上起動しているとき、メニューバーのアイコンを 🌸 1 つにします。機能はそれぞれのアプリのままです。":
        "当两个或以上的 tsubomi 应用正在运行时，菜单栏只显示一个 🌸 图标。各应用的功能保持不变。",
    "メニューバー": "菜单栏",
    "表示のしかた": "图标显示",
    "1 つにまとめる": "合并为一个",
    "アプリごとに表示": "每个应用单独显示",
    "🌸 に入れるアプリ": "放入 🌸 的应用",
    "（このアプリ）": "（本应用）",
    "まとめると、メニューバーのアイコンが 🌸 1 つになり、押したあとパネルの上でアプリを切り替えられます。外したアプリは、自分のアイコンを出したままです。機能・ライセンスはそれぞれのアプリのままです。":
        "合并后菜单栏只显示一个 🌸，点按后可在面板顶部切换应用。未放入的应用仍显示自己的图标。各应用的功能和许可保持不变。",
    "一度起動した tsubomi のアプリが、ここに並びます。": "打开过的 tsubomi 应用会显示在这里。",
    "このアプリ": "本应用",
    "起動中": "运行中",
    "開く": "打开",
    "詳しく見る": "了解更多",
    "入っていません": "未安装",
    "tsubomi のほかのアプリも、このアプリと同じ作りで、メニューバーにまとめられます。": "其他 tsubomi 应用采用相同设计，可与本应用共用菜单栏。",
]

/// パネルの下段の文言（アプリの訳の表ではなく、tsubomi-kit の表から引く）。
enum TsubomiText {
    static var settings: String { L("設定…") }
    static var checkForUpdates: String { L("アップデートを確認") }
    static func quit(_ app: String) -> String { L("%@ を終了", app) }
    static func testBuild(_ number: String) -> String { L("テスト版 %@", number) }
}
