import Foundation

/// tsubomi のアプリの一覧（設定 › tsubomi の「tsubomi のアプリ」に並べるもの）。
///
/// 入っていないアプリは、ここに書いた販売ページに案内する。新しいアプリを出したら、ここに足す。
/// 一覧は tsubomi-kit の版に入るので、各アプリが次の版で tsubomi-kit を取り込むと増える。
public struct TsubomiCatalogApp: Identifiable, Hashable, Sendable {
    public var bundleID: String
    public var name: String
    /// 一言の説明（日本語・英語・中国語）。
    public var tagline: Localized
    /// 販売ページ（日本語・英語・中国語）。
    public var page: Localized
    /// アイコン画像（入っていないときに表示する。販売ページに置いてあるもの）。
    public var iconURL: URL

    public var id: String { bundleID }

    public struct Localized: Hashable, Sendable {
        public var ja: String
        public var en: String
        public var zh: String?

        /// アプリが動いている言語のもの。
        public var current: String {
            switch currentLanguage {
            case .ja: return ja
            case .zh: return zh ?? en
            case .en: return en
            }
        }
    }
}

public enum TsubomiCatalog {
    public static let apps: [TsubomiCatalogApp] = [
        TsubomiCatalogApp(
            bundleID: "com.tiast.Profilink",
            name: "Profilink",
            tagline: .init(
                ja: "リンクを、URL に合わせて正しいブラウザ・正しいアカウントで開く",
                en: "Opens every link in the right browser and the right profile",
                zh: "按 URL 用正确的浏览器和账户打开链接"
            ),
            page: .init(
                ja: "https://profilink.tsubomi.jp/",
                en: "https://profilink.tsubomi.jp/en/",
                zh: nil
            ),
            iconURL: URL(string: "https://profilink.tsubomi.jp/appicon.png")!
        ),
        TsubomiCatalogApp(
            bundleID: "com.tiast.TouchRotator",
            name: "TouchRotator",
            tagline: .init(
                ja: "タッチモニターを Mac で使えるように。縦置きの補正・モニター設定・ウィンドウ配置も",
                en: "Makes a touch monitor work on a Mac, with portrait correction and window layout",
                zh: "让触摸显示器在 Mac 上可用，并支持竖屏校正和窗口布局"
            ),
            page: .init(
                ja: "https://touchrotator.tsubomi.jp/",
                en: "https://touchrotator.tsubomi.jp/en/",
                zh: "https://touchrotator.tsubomi.jp/zh/"
            ),
            iconURL: URL(string: "https://touchrotator.tsubomi.jp/appicon.png")!
        ),
    ]
}
