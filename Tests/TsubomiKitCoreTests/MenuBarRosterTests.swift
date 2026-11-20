import XCTest
@testable import TsubomiKitCore

final class MenuBarRosterTests: XCTestCase {
    private func member(_ id: String, _ name: String, pid: Int32, at time: TimeInterval, showsIcon: Bool = true, version: Int = MenuBarProtocol.version) -> MenuBarMember {
        MenuBarMember(bundleID: id, name: name, pid: pid, launchedAt: time, appPath: "/Applications/\(name).app", protocolVersion: version, showsIcon: showsIcon)
    }

    private lazy var profilink = member("com.tiast.Profilink", "Profilink", pid: 100, at: 10)
    private lazy var touch = member("com.tiast.TouchRotator", "TouchRotator", pid: 200, at: 5)
    private lazy var pacer = member("com.tiast.Pacer", "Pacer", pid: 300, at: 20)

    func testAloneAlwaysShowsOwnIcon() {
        let roster = MenuBarRoster(me: profilink)
        XCTAssertEqual(roster.role(preference: .merged), .ownIcon)
        XCTAssertFalse(roster.shouldAskToMerge(preference: .undecided))
    }

    func testAsksOnceWhenASecondAppAppears() {
        var roster = MenuBarRoster(me: profilink)
        roster.upsert(touch)
        XCTAssertTrue(roster.shouldAskToMerge(preference: .undecided))
        XCTAssertFalse(roster.shouldAskToMerge(preference: .merged))
        XCTAssertFalse(roster.shouldAskToMerge(preference: .separate))
        // 答えるまではそれぞれのアイコンのまま。
        XCTAssertEqual(roster.role(preference: .undecided), .ownIcon)
        XCTAssertEqual(roster.role(preference: .separate), .ownIcon)
    }

    func testEarliestLaunchedAppIsTheHostInEveryApp() {
        // TouchRotator が先に起動している。
        var inProfilink = MenuBarRoster(me: profilink)
        inProfilink.upsert(touch)
        inProfilink.upsert(pacer)
        var inTouch = MenuBarRoster(me: touch)
        inTouch.upsert(profilink)
        inTouch.upsert(pacer)

        guard case let .flowerHost(members) = inTouch.role(preference: .merged) else {
            return XCTFail("TouchRotator should host the flower")
        }
        XCTAssertEqual(members.map(\.name), ["Pacer", "Profilink", "TouchRotator"])

        guard case let .hiddenGuest(host, guestMembers) = inProfilink.role(preference: .merged) else {
            return XCTFail("Profilink should hide its icon")
        }
        XCTAssertEqual(host.bundleID, touch.bundleID)
        XCTAssertEqual(guestMembers, members)
    }

    func testTieBreaksOnBundleID() {
        let a = member("com.tiast.A", "A", pid: 1, at: 7)
        let b = member("com.tiast.B", "B", pid: 2, at: 7)
        var roster = MenuBarRoster(me: b)
        roster.upsert(a)
        guard case let .hiddenGuest(host, _) = roster.role(preference: .merged) else {
            return XCTFail("expected guest")
        }
        XCTAssertEqual(host.bundleID, "com.tiast.A")
    }

    func testHostQuittingHandsTheFlowerOn() {
        var roster = MenuBarRoster(me: profilink)
        roster.upsert(touch)
        XCTAssertFalse(roster.role(preference: .merged).showsOwnIcon)
        roster.remove(bundleID: touch.bundleID, pid: touch.pid)
        // 1 つだけになったら自分のアイコンに戻る。
        XCTAssertEqual(roster.role(preference: .merged), .ownIcon)

        roster.upsert(touch)
        roster.upsert(pacer)
        roster.remove(bundleID: touch.bundleID, pid: touch.pid)
        guard case .flowerHost = roster.role(preference: .merged) else {
            return XCTFail("Profilink should take over the flower")
        }
    }

    func testAppsHidingTheirIconDoNotTakePart() {
        var roster = MenuBarRoster(me: profilink)
        roster.upsert(member("com.tiast.TouchRotator", "TouchRotator", pid: 200, at: 5, showsIcon: false))
        XCTAssertEqual(roster.role(preference: .merged), .ownIcon)
        XCTAssertFalse(roster.shouldAskToMerge(preference: .undecided))

        // 自分がアイコンを隠しているときも参加しない。
        var hidden = MenuBarRoster(me: member("com.tiast.Profilink", "Profilink", pid: 100, at: 10, showsIcon: false))
        hidden.upsert(touch)
        hidden.upsert(pacer)
        XCTAssertEqual(hidden.role(preference: .merged), .ownIcon)
    }

    func testAppsOnAnotherProtocolVersionAreLeftAlone() {
        var roster = MenuBarRoster(me: profilink)
        roster.upsert(member("com.tiast.TouchRotator", "TouchRotator", pid: 200, at: 5, version: MenuBarProtocol.version + 1))
        XCTAssertEqual(roster.role(preference: .merged), .ownIcon)
    }

    func testIgnoresItselfAndStaleAnnouncements() {
        var roster = MenuBarRoster(me: profilink)
        XCTAssertFalse(roster.upsert(profilink))
        // 同じアプリの別プロセス（開発中の二重起動）も相手にしない。
        XCTAssertFalse(roster.upsert(member("com.tiast.Profilink", "Profilink", pid: 999, at: 50)))

        let relaunched = member("com.tiast.TouchRotator", "TouchRotator", pid: 201, at: 30)
        XCTAssertTrue(roster.upsert(relaunched))
        // 起動し直す前のプロセスの知らせが遅れて届いても、新しいほうを残す。
        XCTAssertFalse(roster.upsert(touch))
        XCTAssertEqual(roster.others["com.tiast.TouchRotator"]?.pid, 201)
        // 古いプロセスの「終了します」で、新しいほうを消さない。
        XCTAssertFalse(roster.remove(bundleID: touch.bundleID, pid: 200))
        XCTAssertNotNil(roster.others["com.tiast.TouchRotator"])
        // 同じ知らせが二度届いても「変わった」とは言わない。
        XCTAssertFalse(roster.upsert(relaunched))
    }

    func testPruneDropsAppsThatDiedWithoutSayingGoodbye() {
        var roster = MenuBarRoster(me: profilink)
        roster.upsert(touch)
        roster.upsert(pacer)
        XCTAssertTrue(roster.prune(isAlive: { $0 != 200 }))
        XCTAssertNil(roster.others[touch.bundleID])
        XCTAssertNotNil(roster.others[pacer.bundleID])
        XCTAssertFalse(roster.prune(isAlive: { _ in true }))
    }

    func testExcludedAppsKeepTheirOwnIconWhileTheRestShareTheFlower() {
        // 3 つのうち、Pacer だけ 🌸 から外す。
        var inPacer = MenuBarRoster(me: pacer)
        inPacer.upsert(profilink)
        inPacer.upsert(touch)
        inPacer.excluded = ["com.tiast.Pacer"]
        XCTAssertEqual(inPacer.role(preference: .merged), .ownIcon)
        XCTAssertFalse(inPacer.shouldAskToMerge(preference: .undecided))

        var inTouch = MenuBarRoster(me: touch)
        inTouch.upsert(profilink)
        inTouch.upsert(pacer)
        inTouch.excluded = ["com.tiast.Pacer"]
        guard case let .flowerHost(members) = inTouch.role(preference: .merged) else {
            return XCTFail("TouchRotator should still host the flower")
        }
        XCTAssertEqual(members.map(\.name), ["Profilink", "TouchRotator"])
    }

    func testFlowerGoesAwayWhenOnlyOneAppIsLeftInIt() {
        var roster = MenuBarRoster(me: profilink)
        roster.upsert(touch)
        roster.excluded = ["com.tiast.TouchRotator"]
        XCTAssertEqual(roster.role(preference: .merged), .ownIcon)
        roster.excluded = []
        XCTAssertTrue(roster.role(preference: .merged).isMerged)
    }
}
