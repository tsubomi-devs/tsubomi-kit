import Foundation

/// アプリ同士でやり取りする知らせ。JSON にして、Mac のアプリ間通知の userInfo に入れて送る。
///
/// 版が上がって種類が増えても古いアプリが壊れないよう、enum の関連値ではなく、
/// 「種類」と「あれば入っている項目」の形にしている。知らない種類は読み飛ばす。
public struct MenuBarMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// 「起動しています」。起動したとき、聞かれたとき、設定が変わったときに送る。
        case announce
        /// 「起動しているアプリは名乗ってください」。起動したときに送る。
        case query
        /// 「終了します」。
        case goodbye
        /// 「`target` のアプリは、`anchor` の下にパネルを出してください」。
        case show
        /// 「`target` のアプリは、パネルを閉じてください」。
        case hide
        /// 「パネルを開いた／閉じた」。🌸 を出しているアプリが、押されたときに開くか閉じるかを決めるのに使う。
        case panelState
        /// 「共通の設定（まとめる／まとめない）が変わった」。受け取ったら設定を読み直す。
        case preferencesChanged
        /// 「tsubomi のアプリは、アップデートがないか確かめてください」。どれかのパネルで ↓ を押したときに送る。
        /// 受け取ったアプリは、ふだんの自動の確認と同じように確かめ、新しい版があるときだけ知らせる。
        case checkForUpdates
    }

    public var kind: Kind
    /// 送ったアプリのバンドル ID。
    public var sender: String
    /// 送ったアプリのプロセス番号。自分が送った知らせを読み飛ばすのに使う。
    public var senderPID: Int32
    /// announce のとき：送ったアプリの情報。
    public var member: MenuBarMember?
    /// show / hide のとき：パネルを出す・閉じるアプリのバンドル ID。
    public var target: String?
    /// show のとき：パネルを出す位置の目印（🌸 アイコンの、画面上の四角）。
    public var anchor: MenuBarRect?
    /// panelState のとき：開いたか。
    public var isOpen: Bool?
    /// 送った時刻（1970 年からの秒）。
    public var sentAt: TimeInterval

    public init(
        kind: Kind,
        sender: String,
        senderPID: Int32,
        member: MenuBarMember? = nil,
        target: String? = nil,
        anchor: MenuBarRect? = nil,
        isOpen: Bool? = nil,
        sentAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.kind = kind
        self.sender = sender
        self.senderPID = senderPID
        self.member = member
        self.target = target
        self.anchor = anchor
        self.isOpen = isOpen
        self.sentAt = sentAt
    }

    /// 送るための文字列（JSON）。
    public func encoded() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 受け取った文字列から読む。形が違う・知らない種類のときは nil（読み飛ばす）。
    public static func decode(_ string: String) -> MenuBarMessage? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MenuBarMessage.self, from: data)
    }
}

/// 画面上の四角（AppKit の画面座標。左下が原点）。CGRect は Linux の Foundation で
/// Codable の形が違うことがあるので、自前の形で送る。
public struct MenuBarRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
}
