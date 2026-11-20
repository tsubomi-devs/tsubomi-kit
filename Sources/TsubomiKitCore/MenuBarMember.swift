import Foundation

/// メニューバーのアイコンをまとめる仕組みに参加している、起動中の tsubomi のアプリ 1 つ。
///
/// 各アプリは起動したときと、ほかのアプリに聞かれたときに、自分のことをこの形で知らせる。
public struct MenuBarMember: Codable, Hashable, Sendable {
    /// バンドル ID（例: com.tiast.Profilink）。アプリを見分ける名前。
    public var bundleID: String
    /// 画面に出す名前（例: Profilink）。
    public var name: String
    /// プロセス番号。同じアプリが終了して起動し直したときに、古い知らせと見分ける。
    public var pid: Int32
    /// 起動した時刻（1970 年からの秒）。🌸 を出す担当は、いちばん先に起動したアプリ。
    public var launchedAt: TimeInterval
    /// .app の場所。切り替えにアイコンを出したり、起動していないときに開いたりするのに使う。
    public var appPath: String
    /// まとめる仕組みの版。版の大きく違うアプリとはまとめない。
    public var protocolVersion: Int
    /// メニューバーにアイコンを出しているか。アプリの設定でアイコンを隠しているときは false で、
    /// そのアプリは切り替えに出さず、🌸 の担当にもならない。
    public var showsIcon: Bool

    public init(
        bundleID: String,
        name: String,
        pid: Int32,
        launchedAt: TimeInterval,
        appPath: String,
        protocolVersion: Int = MenuBarProtocol.version,
        showsIcon: Bool = true
    ) {
        self.bundleID = bundleID
        self.name = name
        self.pid = pid
        self.launchedAt = launchedAt
        self.appPath = appPath
        self.protocolVersion = protocolVersion
        self.showsIcon = showsIcon
    }

    /// まとめる相手にできるか（同じ版で、アイコンを出している）。
    public var canMerge: Bool {
        showsIcon && protocolVersion == MenuBarProtocol.version
    }
}

/// まとめる仕組みの決まりごと。
public enum MenuBarProtocol {
    /// やり取りの形を変えたら上げる。版の違うアプリとはまとめず、それぞれ自分のアイコンを出す。
    public static let version = 1

    /// アプリ同士の知らせの名前（Mac のアプリ間通知）。
    public static let notificationName = "works.tsubomi.menubar"

    /// 知らせの中身を入れる userInfo のキー。
    public static let payloadKey = "payload"

    /// tsubomi のアプリで共通の設定を置く場所（~/Library/Preferences/works.tsubomi.shared.plist）。
    public static let sharedDefaultsSuite = "works.tsubomi.shared"
}

/// これまでに起動したことのある tsubomi のアプリ。起動していないときも切り替えに薄く出し、
/// 押すと起動できるようにするために覚えておく。
public struct KnownApp: Codable, Hashable, Sendable {
    public var bundleID: String
    public var name: String
    public var appPath: String

    public init(bundleID: String, name: String, appPath: String) {
        self.bundleID = bundleID
        self.name = name
        self.appPath = appPath
    }

    public init(_ member: MenuBarMember) {
        self.init(bundleID: member.bundleID, name: member.name, appPath: member.appPath)
    }
}
