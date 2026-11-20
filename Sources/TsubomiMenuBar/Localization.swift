import Foundation

/// この部品の文言。キーは日本語の原文（Profilink・TouchRotator と同じ方式）。
///
/// 訳はファイル（.lproj）ではなく、ここに持つ。SwiftPM のリソースは別のバンドルになり、
/// アプリの .app を Makefile で組み立てるときに入れ忘れると、Bundle.module が見つからずに
/// 起動時に落ちる。コードの中に持てば、何もコピーしなくても動く。
///
/// 言語は、アプリ自身が選んだ言語（Bundle.main の preferredLocalizations）に合わせる。
/// アプリが英語で動いているなら英語、日本語なら日本語（キーのまま）、
/// 中国語（簡体字。TouchRotator が対応している）なら中国語。それ以外は英語。
func L(_ key: String) -> String {
    let language = Bundle.main.preferredLocalizations.first ?? "ja"
    if language.hasPrefix("ja") { return key }
    if language.hasPrefix("zh") { return chinese[key] ?? english[key] ?? key }
    return english[key] ?? key
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}

private let english: [String: String] = [
    "tsubomi のアプリ": "tsubomi apps",
    "アプリを選ぶ": "Choose an app",
    "%@ を起動して開く": "Open %@",
    "メニューバーのアイコンをまとめますか？": "Combine the menu bar icons?",
    "%@ も起動しています。tsubomi のアプリのアイコンを 1 つにまとめ、押したあとに上で切り替えられます。設定でいつでも戻せます。":
        "%@ is also running. Show one icon for all tsubomi apps and switch between them at the top of the panel. You can change this in Settings at any time.",
    "、": ", ",
    "別々のまま": "Keep Separate",
    "まとめる": "Combine",
    "tsubomi のアプリをメニューバーで 1 つにまとめる": "Combine tsubomi apps into one menu bar icon",
    "tsubomi のアプリが 2 つ以上起動しているとき、メニューバーのアイコンを 🌸 1 つにします。機能はそれぞれのアプリのままです。":
        "When two or more tsubomi apps are running, show a single 🌸 icon in the menu bar. Each app keeps all of its own features.",
]

private let chinese: [String: String] = [
    "tsubomi のアプリ": "tsubomi 应用",
    "アプリを選ぶ": "选择应用",
    "%@ を起動して開く": "打开 %@",
    "メニューバーのアイコンをまとめますか？": "要合并菜单栏图标吗？",
    "%@ も起動しています。tsubomi のアプリのアイコンを 1 つにまとめ、押したあとに上で切り替えられます。設定でいつでも戻せます。":
        "%@ 也在运行。可将 tsubomi 应用的图标合并为一个，点按后在面板顶部切换。随时可在设置中更改。",
    "、": "、",
    "別々のまま": "保持分开",
    "まとめる": "合并",
    "tsubomi のアプリをメニューバーで 1 つにまとめる": "将 tsubomi 应用合并为一个菜单栏图标",
    "tsubomi のアプリが 2 つ以上起動しているとき、メニューバーのアイコンを 🌸 1 つにします。機能はそれぞれのアプリのままです。":
        "当两个或以上的 tsubomi 应用正在运行时，菜单栏只显示一个 🌸 图标。各应用的功能保持不变。",
]
