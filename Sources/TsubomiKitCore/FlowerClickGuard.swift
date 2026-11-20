import Foundation

/// 🌸 を押したときに、パネルを開くか閉じるかを決める。
///
/// ほかのアプリのパネルが開いているときに 🌸 を押すと、そのアプリは「パネルの外が押された」と
/// 気づいて先に自分でパネルを閉じ、「閉じた」と知らせてくる。その知らせは 🌸 のボタンの処理より
/// 先に届くことがあるので、「たった今閉じた」ものは、押す直前まで開いていたとみなす。
/// そうしないと、閉じるつもりで押した 🌸 が、パネルをもう一度開いてしまう。
public struct FlowerClickGuard: Equatable, Sendable {
    /// これより短い間に閉じたパネルは、押す直前まで開いていたとみなす（秒）。
    public static let recentCloseWindow: TimeInterval = 0.45

    /// いまパネルを開いているアプリ（なければ nil）。
    public private(set) var openApp: String?
    /// 最後にパネルが閉じた時刻。
    public private(set) var lastClosedAt: TimeInterval = -.infinity

    public init() {}

    /// パネルが開いた／閉じたことを受け取る。
    public mutating func record(app: String, isOpen: Bool, at time: TimeInterval) {
        if isOpen {
            openApp = app
        } else if openApp == app || openApp == nil {
            openApp = nil
            lastClosedAt = max(lastClosedAt, time)
        }
    }

    public enum Decision: Equatable, Sendable {
        /// `app` のパネルを開く。
        case open(String)
        /// `app` のパネルを閉じる。
        case close(String)
        /// 何もしない（たった今閉じたところ）。
        case none
    }

    /// 🌸 が押された。`preferred` は開くアプリ（最後に開いたアプリ、なければ担当自身）。
    public func decide(clickAt time: TimeInterval, preferred: String) -> Decision {
        if let openApp {
            return .close(openApp)
        }
        if time - lastClosedAt < Self.recentCloseWindow {
            return .none
        }
        return .open(preferred)
    }
}
