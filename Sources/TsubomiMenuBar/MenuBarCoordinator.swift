import AppKit
import Combine
import TsubomiKitCore

/// パネルを出す・閉じるなど、まとめる仕組みからメニューバー側に頼むこと。
@MainActor
protocol MenuBarCoordinatorDelegate: AnyObject {
    /// 役割（自分のアイコン／🌸 の担当／アイコンを隠す）が変わった。
    func coordinatorDidChangeRole(_ coordinator: TsubomiMenuBarCoordinator)
    /// ほかのアプリ（🌸 の担当や切り替え）から、`anchor` の下にパネルを出すよう頼まれた。
    func coordinator(_ coordinator: TsubomiMenuBarCoordinator, showPanelBelow anchor: NSRect)
    /// ほかのアプリから、パネルを閉じるよう頼まれた。
    func coordinatorRequestsHide(_ coordinator: TsubomiMenuBarCoordinator)
}

/// 起動中の tsubomi のアプリと知らせ合い、メニューバーでの役割を決める。
///
/// Mac のアプリ間通知（DistributedNotificationCenter）で短い知らせをやり取りするだけで、
/// サーバーも、まとめ役の別アプリも要らない。どのアプリも同じ決め方で 🌸 の担当を選ぶ。
@MainActor
public final class TsubomiMenuBarCoordinator: ObservableObject {
    /// 自分の役割。
    @Published public private(set) var role: MenuBarRole = .ownIcon
    /// 共通の設定（まとめる／まとめない／まだ聞いていない）。
    @Published public private(set) var preference: MergePreference
    /// 「まとめますか？」をパネルに出すか。
    @Published public private(set) var asksToMerge = false
    /// これまでに起動したことのある tsubomi のアプリ（自分を含む）。
    @Published public private(set) var knownApps: [KnownApp] = []
    /// 🌸 に入れないアプリ（バンドル ID）。全アプリで共通。
    @Published public private(set) var excludedApps: Set<String> = []

    weak var delegate: MenuBarCoordinatorDelegate?

    private(set) var roster: MenuBarRoster
    private(set) var clickGuard = FlowerClickGuard()
    private let defaults: UserDefaults
    private let center = DistributedNotificationCenter.default()
    private var observers: [NSObjectProtocol] = []
    /// アプリの「メニューバーにアイコンを表示」の設定。
    private var iconVisible = true
    /// 起動していないアプリを切り替えから起動したとき、名乗ってきたらパネルを出してもらう。
    private var pendingShow: (bundleID: String, anchor: MenuBarRect, until: Date)?

    private enum Key {
        static let merge = "menuBarMerge"
        static let lastOpened = "menuBarLastOpenedApp"
        static let knownApps = "menuBarKnownApps"
        static let excluded = "menuBarExcludedApps"
    }

    init(appName: String) {
        let bundle = Bundle.main
        let me = MenuBarMember(
            bundleID: bundle.bundleIdentifier ?? appName,
            name: appName,
            pid: ProcessInfo.processInfo.processIdentifier,
            launchedAt: (NSRunningApplication.current.launchDate ?? Date()).timeIntervalSince1970,
            appPath: bundle.bundlePath
        )
        roster = MenuBarRoster(me: me)
        defaults = UserDefaults(suiteName: MenuBarProtocol.sharedDefaultsSuite) ?? .standard
        preference = Self.readPreference(defaults)
        knownApps = Self.readKnownApps(defaults)
        excludedApps = Self.readExcluded(defaults)
        roster.excluded = excludedApps
        remember(KnownApp(me))
        updateAnnouncedIcon()
    }

    public var me: MenuBarMember { roster.me }

    // MARK: 開始・終了

    func start() {
        observers.append(center.addObserver(
            forName: Notification.Name(MenuBarProtocol.notificationName),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let text = note.userInfo?[MenuBarProtocol.payloadKey] as? String,
                  let message = MenuBarMessage.decode(text) else { return }
            Task { @MainActor [weak self] in self?.receive(message) }
        })
        // 終了の知らせを出せずに落ちたアプリも、プロセスの終了で気づく。
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            let pid = app.processIdentifier
            Task { @MainActor [weak self] in
                guard let self, self.roster.remove(bundleID: bundleID, pid: pid) else { return }
                self.clickGuard.record(app: bundleID, isOpen: false, at: Date().timeIntervalSince1970)
                self.recompute()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(.goodbye) }
        })

        send(.query)
        send(.announce, member: me)
        recompute()
    }

    // MARK: 自分の状態

    /// メニューバーにアイコンを出すか（アプリの設定）。隠しているときはまとめる仕組みにも参加しない。
    func setShowsIcon(_ shows: Bool) {
        iconVisible = shows
        if updateAnnouncedIcon() {
            send(.announce, member: me)
        }
        recompute()
    }

    /// ほかのアプリに知らせる showsIcon（🌸 に入るか）を合わせ直す。変わったら true。
    ///
    /// 🌸 から外したアプリは、自分のアイコンは出したまま、ほかのアプリには「アイコンを
    /// 出していない」と名乗る。そうすれば、外す仕組みを知らない前の版（Profilink 1.1.4・
    /// TouchRotator 1.66.8）も、そのアプリを 🌸 に入れない。
    @discardableResult
    private func updateAnnouncedIcon() -> Bool {
        let joins = iconVisible && !excludedApps.contains(roster.me.bundleID)
        guard roster.me.showsIcon != joins else { return false }
        var me = roster.me
        me.showsIcon = joins
        roster.updateMe(me)
        return true
    }

    /// 自分のパネルが開いた／閉じた。
    func panelDidChange(isOpen: Bool) {
        clickGuard.record(app: me.bundleID, isOpen: isOpen, at: Date().timeIntervalSince1970)
        if isOpen {
            defaults.set(me.bundleID, forKey: Key.lastOpened)
        }
        if role.isMerged {
            send(.panelState, isOpen: isOpen)
        }
    }

    // MARK: 設定

    /// 共通の設定を変える。すべての tsubomi のアプリに伝わる。
    public func setPreference(_ value: MergePreference) {
        defaults.set(value.rawValue, forKey: Key.merge)
        preference = value
        send(.preferencesChanged)
        recompute()
    }

    /// `bundleID` のアプリを 🌸 に入れる／外す。すべての tsubomi のアプリに伝わる。
    public func setIncluded(_ included: Bool, bundleID: String) {
        var set = Self.readExcluded(defaults)
        if included { set.remove(bundleID) } else { set.insert(bundleID) }
        defaults.set(Array(set).sorted(), forKey: Key.excluded)
        applyExcluded(set)
        send(.preferencesChanged)
    }

    /// `bundleID` のアプリが起動中か（自分を含む）。
    public func isRunning(_ bundleID: String) -> Bool {
        bundleID == me.bundleID || roster.others[bundleID] != nil
            || !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private func applyExcluded(_ set: Set<String>) {
        guard set != excludedApps else { return }
        excludedApps = set
        roster.excluded = set
        if updateAnnouncedIcon() {
            send(.announce, member: me)
        }
        recompute()
    }

    // MARK: 🌸 と切り替え

    /// 🌸 が押された（担当のアプリだけが呼ぶ）。
    func flowerClicked(anchor: NSRect) {
        let members = role.members.map(\.bundleID)
        var preferred = defaults.string(forKey: Key.lastOpened) ?? me.bundleID
        if !members.contains(preferred) { preferred = me.bundleID }
        switch clickGuard.decide(clickAt: Date().timeIntervalSince1970, preferred: preferred) {
        case let .open(bundleID):
            open(bundleID, below: anchor)
        case let .close(bundleID):
            if bundleID == me.bundleID {
                delegate?.coordinatorRequestsHide(self)
            } else {
                send(.hide, target: bundleID)
            }
        case .none:
            break
        }
    }

    /// 切り替えで選ばれたアプリのパネルを出す。起動していなければ起動して、名乗ってきたら出す。
    func open(_ bundleID: String, below anchor: NSRect) {
        if bundleID == me.bundleID {
            delegate?.coordinator(self, showPanelBelow: anchor)
            return
        }
        let rect = MenuBarRect(anchor)
        if roster.others[bundleID] != nil {
            send(.show, target: bundleID, anchor: rect)
        } else if let known = knownApps.first(where: { $0.bundleID == bundleID }) {
            pendingShow = (bundleID, rect, Date().addingTimeInterval(15))
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: known.appPath), configuration: configuration) { _, _ in }
        }
    }

    /// 切り替えに並べるアプリ：起動中のもの（role.members）と、起動していない覚えているもの。
    var switcherItems: [SwitcherItem] {
        let running = role.members
        let runningIDs = Set(running.map(\.bundleID))
        var items = running.map { SwitcherItem(bundleID: $0.bundleID, name: $0.name, appPath: $0.appPath, isRunning: true) }
        for app in knownApps where !runningIDs.contains(app.bundleID)
            && roster.others[app.bundleID] == nil
            && !excludedApps.contains(app.bundleID)
            && FileManager.default.fileExists(atPath: app.appPath) {
            items.append(SwitcherItem(bundleID: app.bundleID, name: app.name, appPath: app.appPath, isRunning: false))
        }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: 受け取り

    private func receive(_ message: MenuBarMessage) {
        if message.sender == me.bundleID && message.senderPID == me.pid { return }
        switch message.kind {
        case .query:
            prune()
            send(.announce, member: me)
        case .announce:
            guard let member = message.member else { return }
            prune()
            let changed = roster.upsert(member)
            if roster.others[member.bundleID] == member {
                remember(KnownApp(member))
            }
            if changed { recompute() }
            if let pending = pendingShow, pending.bundleID == member.bundleID {
                pendingShow = nil
                if pending.until > Date() {
                    send(.show, target: member.bundleID, anchor: pending.anchor)
                }
            }
        case .goodbye:
            if roster.remove(bundleID: message.sender, pid: message.senderPID) {
                clickGuard.record(app: message.sender, isOpen: false, at: message.sentAt)
                recompute()
            }
        case .show:
            guard message.target == me.bundleID, let anchor = message.anchor else { return }
            delegate?.coordinator(self, showPanelBelow: NSRect(anchor))
        case .hide:
            guard message.target == me.bundleID else { return }
            delegate?.coordinatorRequestsHide(self)
        case .panelState:
            clickGuard.record(app: message.sender, isOpen: message.isOpen ?? false, at: message.sentAt)
            if message.isOpen == true {
                defaults.set(message.sender, forKey: Key.lastOpened)
            }
        case .preferencesChanged:
            let value = Self.readPreference(defaults)
            if value != preference {
                preference = value
                recompute()
            }
            applyExcluded(Self.readExcluded(defaults))
        }
    }

    private func prune() {
        if roster.prune(isAlive: { NSRunningApplication(processIdentifier: $0) != nil }) {
            recompute()
        }
    }

    private func recompute() {
        let newRole = roster.role(preference: preference)
        let newAsk = roster.shouldAskToMerge(preference: preference)
        if newAsk != asksToMerge { asksToMerge = newAsk }
        guard newRole != role else { return }
        role = newRole
        delegate?.coordinatorDidChangeRole(self)
    }

    // MARK: 送る

    private func send(
        _ kind: MenuBarMessage.Kind,
        member: MenuBarMember? = nil,
        target: String? = nil,
        anchor: MenuBarRect? = nil,
        isOpen: Bool? = nil
    ) {
        let message = MenuBarMessage(
            kind: kind,
            sender: me.bundleID,
            senderPID: me.pid,
            member: member,
            target: target,
            anchor: anchor,
            isOpen: isOpen
        )
        guard let text = message.encoded() else { return }
        center.postNotificationName(
            Notification.Name(MenuBarProtocol.notificationName),
            object: nil,
            userInfo: [MenuBarProtocol.payloadKey: text],
            deliverImmediately: true
        )
    }

    // MARK: 共通の設定の読み書き

    private static func readPreference(_ defaults: UserDefaults) -> MergePreference {
        defaults.string(forKey: Key.merge).flatMap(MergePreference.init(rawValue:)) ?? .undecided
    }

    private static func readExcluded(_ defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: Key.excluded) ?? [])
    }

    private static func readKnownApps(_ defaults: UserDefaults) -> [KnownApp] {
        guard let data = defaults.data(forKey: Key.knownApps),
              let apps = try? JSONDecoder().decode([KnownApp].self, from: data) else { return [] }
        return apps
    }

    private func remember(_ app: KnownApp) {
        var apps = Self.readKnownApps(defaults)
        if let index = apps.firstIndex(where: { $0.bundleID == app.bundleID }) {
            guard apps[index] != app else {
                knownApps = apps
                return
            }
            apps[index] = app
        } else {
            apps.append(app)
        }
        if let data = try? JSONEncoder().encode(apps) {
            defaults.set(data, forKey: Key.knownApps)
        }
        knownApps = apps
    }
}

/// 切り替えに並べるアプリ 1 つ。
struct SwitcherItem: Identifiable, Equatable {
    var bundleID: String
    var name: String
    var appPath: String
    var isRunning: Bool
    var id: String { bundleID }
}

extension MenuBarRect {
    init(_ rect: NSRect) {
        self.init(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
    }
}

extension NSRect {
    init(_ rect: MenuBarRect) {
        self.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
