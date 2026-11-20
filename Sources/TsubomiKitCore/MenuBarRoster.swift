import Foundation

/// 共通の設定「tsubomi のアプリをメニューバーで 1 つにまとめる」。
public enum MergePreference: String, Codable, Sendable {
    /// まだ聞いていない。tsubomi のアプリが 2 つ以上起動したら、パネルで一度だけ聞く。
    case undecided
    /// まとめる（🌸 を 1 つだけ出す）。
    case merged
    /// まとめない（それぞれのアプリがアイコンを出す）。
    case separate
}

/// 自分のアプリが、いまメニューバーでどう振る舞うか。
public enum MenuBarRole: Equatable, Sendable {
    /// 自分のアイコンを出す（まとめない・ほかに tsubomi のアプリがない）。
    case ownIcon
    /// 🌸 を出す担当。`members` は切り替えに並べるアプリ（自分を含む、並び順どおり）。
    case flowerHost(members: [MenuBarMember])
    /// アイコンを隠す。パネルは 🌸 の担当から頼まれたときに出す。
    case hiddenGuest(host: MenuBarMember, members: [MenuBarMember])

    public var showsOwnIcon: Bool {
        if case .ownIcon = self { return true }
        return false
    }

    public var isMerged: Bool { !showsOwnIcon }

    /// 切り替えに並べるアプリ。まとめていないときは空。
    public var members: [MenuBarMember] {
        switch self {
        case .ownIcon: return []
        case let .flowerHost(members): return members
        case let .hiddenGuest(_, members): return members
        }
    }
}

/// 起動中の tsubomi のアプリの一覧と、そこから決まる自分の役割。
///
/// どのアプリも同じ一覧から同じ決め方で担当を選ぶので、相談しなくても担当は 1 つに決まる。
public struct MenuBarRoster: Equatable, Sendable {
    /// 自分のアプリ。
    public private(set) var me: MenuBarMember
    /// 自分以外の、起動中のアプリ（バンドル ID ごとに 1 つ）。
    public private(set) var others: [String: MenuBarMember] = [:]
    /// 🌸 に入れないアプリ（設定 › tsubomi で外したもの。バンドル ID）。
    /// 外したアプリは、まとめているあいだも自分のアイコンを出す。
    public var excluded: Set<String> = []

    public init(me: MenuBarMember) {
        self.me = me
    }

    /// 自分の情報を変える（アイコンを隠す設定を変えたときなど）。
    public mutating func updateMe(_ member: MenuBarMember) {
        me = member
    }

    /// ほかのアプリの名乗りを受け取る。自分の知らせ・古い知らせは無視する。
    /// 一覧が変わったら true。
    @discardableResult
    public mutating func upsert(_ member: MenuBarMember) -> Bool {
        if member.bundleID == me.bundleID && member.pid == me.pid { return false }
        if member.bundleID == me.bundleID {
            // 同じアプリの別のプロセス（開発中の二重起動など）。まとめる相手にはしない。
            return false
        }
        if let existing = others[member.bundleID], existing.pid != member.pid,
           existing.launchedAt > member.launchedAt {
            // 新しく起動し直したあとに、前のプロセスの古い知らせが届いた。
            return false
        }
        guard others[member.bundleID] != member else { return false }
        others[member.bundleID] = member
        return true
    }

    /// アプリが終了した。プロセス番号が違えば（もう起動し直している）消さない。
    @discardableResult
    public mutating func remove(bundleID: String, pid: Int32) -> Bool {
        guard let existing = others[bundleID], existing.pid == pid else { return false }
        others[bundleID] = nil
        return true
    }

    /// プロセスが生きていないアプリを消す（終了の知らせを出せずに落ちた場合など）。
    @discardableResult
    public mutating func prune(isAlive: (Int32) -> Bool) -> Bool {
        let dead = others.values.filter { !isAlive($0.pid) }
        for member in dead {
            others[member.bundleID] = nil
        }
        return !dead.isEmpty
    }

    /// まとめる相手にできるアプリ（自分を含む）。先に起動した順。
    public var mergeCandidates: [MenuBarMember] {
        let all = [me] + Array(others.values)
        return all.filter(joinsFlower).sorted(by: Self.hostOrder)
    }

    /// まとめられる相手がいるか（自分を含めて 2 つ以上）。
    public var hasMergePartners: Bool {
        joinsFlower(me) && mergeCandidates.count >= 2
    }

    /// 🌸 に入るアプリか（まとめられる版で、アイコンを出していて、外されていない）。
    public func joinsFlower(_ member: MenuBarMember) -> Bool {
        member.canMerge && !excluded.contains(member.bundleID)
    }

    /// まとめるか一度だけ聞く場面か。
    public func shouldAskToMerge(preference: MergePreference) -> Bool {
        preference == .undecided && hasMergePartners
    }

    /// 自分の役割。
    public func role(preference: MergePreference) -> MenuBarRole {
        guard preference == .merged, hasMergePartners else { return .ownIcon }
        let candidates = mergeCandidates
        let host = candidates[0]
        // 切り替えの並びは名前順（起動の順番で並びが変わらないように）。
        let members = candidates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if host.bundleID == me.bundleID {
            return .flowerHost(members: members)
        }
        return .hiddenGuest(host: host, members: members)
    }

    /// 担当の決め方：先に起動したアプリ。同時ならバンドル ID、さらにプロセス番号の順。
    static func hostOrder(_ a: MenuBarMember, _ b: MenuBarMember) -> Bool {
        if a.launchedAt != b.launchedAt { return a.launchedAt < b.launchedAt }
        if a.bundleID != b.bundleID { return a.bundleID < b.bundleID }
        return a.pid < b.pid
    }
}
