import AppKit

extension NSWindow {
    /// 設定の窓のツールバーから、サイドバーの開閉ボタン（「サイドバーを非表示」）を消し続ける。
    ///
    /// システム設定にはこのボタンがなく、項目の少ない設定ではたたむものもない。SwiftUI の
    /// `toolbar(removing: .sidebarToggle)` は効かず（ボタンが残る）、これまでは窓を開いてから
    /// 1.5 秒のあいだ何度か見に行って消していた。ところが、そのあとで SwiftUI がボタンを
    /// 入れ直すことがあり、窓の右上の「>>」（入りきらない項目の置き場）に残っていた。
    ///
    /// そこで、ツールバーに項目が足されるたびに見て、開閉ボタンならすぐ消す。窓が前に
    /// 出たときにも見直す。何度呼んでも、見張りは窓ごとに 1 つだけ。設定の窓は閉じても
    /// 使い回すので、見張りは残しておく。
    public func keepSidebarToggleAway() {
        removeSidebarToggleItems()
        // SwiftUI は分割ビューを並べながらボタンを入れるので、最初のうちは何度か見る。
        for delay in [0.1, 0.3, 0.6, 1.0, 1.5] as [Double] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.removeSidebarToggleItems()
            }
        }

        let key = ObjectIdentifier(self)
        guard SidebarToggleWatch.tokens[key] == nil else { return }
        var tokens: [NSObjectProtocol] = []
        // ツールバーは SwiftUI が作り直すことがあるので、どのツールバーでも受け、この窓のものか確かめる。
        tokens.append(NotificationCenter.default.addObserver(
            forName: NSToolbar.willAddItemNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let toolbar = note.object as? NSToolbar,
                  toolbar === self.toolbar,
                  let item = note.userInfo?["item"] as? NSToolbarItem,
                  Self.isSidebarToggle(item.itemIdentifier) else { return }
            // 足される途中では消せないので、次の周回で消す。
            DispatchQueue.main.async { [weak self] in self?.removeSidebarToggleItems() }
        })
        tokens.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.removeSidebarToggleItems()
        })
        SidebarToggleWatch.tokens[key] = tokens
    }

    private func removeSidebarToggleItems() {
        guard let toolbar else { return }
        for index in toolbar.items.indices.reversed() where Self.isSidebarToggle(toolbar.items[index].itemIdentifier) {
            toolbar.removeItem(at: index)
        }
    }

    private static func isSidebarToggle(_ identifier: NSToolbarItem.Identifier) -> Bool {
        identifier == .toggleSidebar
            || identifier.rawValue.localizedCaseInsensitiveContains("toggleSidebar")
    }
}

/// 窓ごとの見張り（通知の受け取り口）を持っておく場所。
private enum SidebarToggleWatch {
    static var tokens: [ObjectIdentifier: [NSObjectProtocol]] = [:]
}
