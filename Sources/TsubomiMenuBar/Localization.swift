import Foundation

/// この部品の文言。キーは日本語の原文（Profilink・TouchRotator と同じ方式）。
///
/// 訳はファイル（.lproj）ではなく、ここに持つ。SwiftPM のリソースは別のバンドルになり、
/// アプリの .app を Makefile で組み立てるときに入れ忘れると、Bundle.module が見つからずに
/// 起動時に落ちる。コードの中に持てば、何もコピーしなくても動く。
///
/// 言語は、アプリ自身が選んだ言語（Bundle.main の preferredLocalizations）に合わせる。
/// アプリが英語で動いているなら英語、日本語なら日本語（キーのまま）。
func L(_ key: String) -> String {
    let language = Bundle.main.preferredLocalizations.first ?? "ja"
    if language.hasPrefix("ja") { return key }
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
