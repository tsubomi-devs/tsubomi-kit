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
        TsubomiCatalogApp(
            bundleID: "com.tiast.Shotdrop",
            name: "Shotdrop",
            tagline: .init(
                ja: "全画面・選択・スクロールして全体を、ショートカット 1 つで撮るスクリーンショット",
                en: "Screenshots of the full screen, a selection or a whole scrolling page, each with one shortcut",
                zh: "用一个快捷键截取全屏、选区或整个滚动页面"
            ),
            page: .init(
                ja: "https://shotdrop.tsubomi.jp/",
                en: "https://shotdrop.tsubomi.jp/en/",
                zh: nil
            ),
            iconURL: URL(string: "https://shotdrop.tsubomi.jp/appicon.png")!
        ),
        TsubomiCatalogApp(
            bundleID: "com.tiast.Windowfit",
            name: "Windowfit",
            tagline: .init(
                ja: "ショートカット 1 つで、ウィンドウを半分・4 分の 1・3 分の 1・最大化に並べる",
                en: "One shortcut puts a window in a half, a quarter, a third or full screen",
                zh: "用一个快捷键把窗口排成一半、四分之一、三分之一或最大化"
            ),
            page: .init(
                ja: "https://windowfit.tsubomi.jp/",
                en: "https://windowfit.tsubomi.jp/en/",
                zh: nil
            ),
            iconURL: URL(string: "https://windowfit.tsubomi.jp/appicon.png")!
        ),
        TsubomiCatalogApp(
            bundleID: "com.tiast.Cleanlock",
            name: "Cleanlock",
            tagline: .init(
                ja: "キーボードやトラックパッドを拭くあいだ入力をロックし、画面を拭くときは真っ暗に",
                en: "Locks the keyboard and trackpad while you clean them, and blacks out the screen while you wipe it",
                zh: "擦拭键盘和触控板时锁定输入，擦拭屏幕时让屏幕全黑"
            ),
            page: .init(
                ja: "https://cleanlock.tsubomi.jp/",
                en: "https://cleanlock.tsubomi.jp/en/",
                zh: nil
            ),
            iconURL: URL(string: "https://cleanlock.tsubomi.jp/appicon.png")!
        ),
    ]
}
