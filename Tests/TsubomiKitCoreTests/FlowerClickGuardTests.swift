import XCTest
@testable import TsubomiKitCore

final class FlowerClickGuardTests: XCTestCase {
    func testOpensThePreferredAppWhenNothingIsOpen() {
        let guardState = FlowerClickGuard()
        XCTAssertEqual(guardState.decide(clickAt: 100, preferred: "P"), .open("P"))
    }

    func testClosesWhateverIsOpen() {
        var guardState = FlowerClickGuard()
        guardState.record(app: "T", isOpen: true, at: 10)
        XCTAssertEqual(guardState.decide(clickAt: 11, preferred: "P"), .close("T"))
    }

    func testDoesNotReopenAPanelThatClosedBecauseTheFlowerWasClicked() {
        var guardState = FlowerClickGuard()
        guardState.record(app: "T", isOpen: true, at: 10)
        // マウスを押した瞬間に、T が「外が押された」と気づいて閉じた。
        guardState.record(app: "T", isOpen: false, at: 20.00)
        // 🌸 のボタンの処理は、マウスを離したときに来る。
        XCTAssertEqual(guardState.decide(clickAt: 20.15, preferred: "T"), .none)
        // しばらくたってからの 🌸 は、普通に開く。
        XCTAssertEqual(guardState.decide(clickAt: 21, preferred: "T"), .open("T"))
    }

    func testSwitchingAppsKeepsTrackOfTheOneThatIsOpen() {
        var guardState = FlowerClickGuard()
        guardState.record(app: "A", isOpen: true, at: 10)
        // 切り替え：B が開いた知らせが、A が閉じた知らせより先に届くことがある。
        guardState.record(app: "B", isOpen: true, at: 11)
        guardState.record(app: "A", isOpen: false, at: 11)
        XCTAssertEqual(guardState.openApp, "B")
        XCTAssertEqual(guardState.decide(clickAt: 15, preferred: "A"), .close("B"))
    }
}
