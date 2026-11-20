import XCTest
@testable import TsubomiKitCore

final class MenuBarMessageTests: XCTestCase {
    func testRoundTripsEveryField() throws {
        let member = MenuBarMember(bundleID: "com.tiast.Profilink", name: "Profilink", pid: 42, launchedAt: 1_700_000_000.5, appPath: "/Applications/Profilink.app")
        let message = MenuBarMessage(
            kind: .show,
            sender: "com.tiast.TouchRotator",
            senderPID: 7,
            member: member,
            target: "com.tiast.Profilink",
            anchor: MenuBarRect(x: 1200, y: 1050, width: 30, height: 24),
            isOpen: true,
            sentAt: 1_700_000_100
        )
        let text = try XCTUnwrap(message.encoded())
        XCTAssertEqual(MenuBarMessage.decode(text), message)
    }

    func testOptionalFieldsMayBeMissing() throws {
        let text = #"{"kind":"query","sender":"com.tiast.Pacer","senderPID":3,"sentAt":5}"#
        let message = try XCTUnwrap(MenuBarMessage.decode(text))
        XCTAssertEqual(message.kind, .query)
        XCTAssertNil(message.member)
        XCTAssertNil(message.anchor)
    }

    func testUnknownKindsAndGarbageAreIgnored() {
        // 新しい版のアプリが送った、知らない種類の知らせ。
        XCTAssertNil(MenuBarMessage.decode(#"{"kind":"dance","sender":"x","senderPID":1,"sentAt":0}"#))
        XCTAssertNil(MenuBarMessage.decode("not json"))
        XCTAssertNil(MenuBarMessage.decode(""))
    }

    func testRectHelpers() {
        let rect = MenuBarRect(x: 10, y: 20, width: 30, height: 40)
        XCTAssertEqual(rect.midX, 25)
        XCTAssertEqual(rect.maxY, 60)
    }
}
