import AppKit
import Combine
import SwiftUI
import TsubomiKitCore

/// tsubomi のアプリのメニューバー：アイコンと、押すと開くガラスのパネル。
///
/// Profilink と TouchRotator がそれぞれ持っていた StatusItemController を共通にしたもの。
/// そのうえで、tsubomi のアプリが 2 つ以上起動しているときに、アイコンを 🌸 1 つにまとめられる。
/// 機能はそれぞれのアプリのまま。まとめるのはアイコンだけで、パネルは各アプリが自分で出す。
///
/// 使い方：
/// ```swift
/// let menuBar = TsubomiMenuBar(appName: "Profilink", icon: MenuBarIcon.active) { close in
///     MenuBarView(close: close).environmentObject(model)
/// }
/// menuBar.redrawWhenChanged(model.objectWillChange)
/// ```
/// パネルの中身（content）は、ガラスの背景・角丸・幅 320・外側の余白 12 を自分で描かない。
/// それらはこの部品が描き、まとめているときは上に切り替えを、まだ聞いていなければ
/// 「まとめますか？」を、中身の上に足す。
@MainActor
public final class TsubomiMenuBar<Content: View>: NSObject {
    /// まとめる仕組み。設定画面の切り替え（TsubomiMergeToggle）に渡す。
    public let coordinator: TsubomiMenuBarCoordinator

    /// アプリのアイコン（白黒のテンプレート画像）。一時停止中などで変えるときに入れ直す。
    public var icon: NSImage {
        didSet { updateStatusItem() }
    }

    /// メニューバーにアイコンを出すか（アプリの「メニューバーにアイコンを表示」の設定）。
    /// 隠しているあいだは、まとめる仕組みにも参加しない。
    public var isIconVisible: Bool = true {
        didSet {
            coordinator.setShowsIcon(isIconVisible)
            updateStatusItem()
        }
    }

    /// パネルを開く直前に呼ぶ（状態を読み直すなど）。
    public var willShowPanel: (() -> Void)?

    /// 撮影モードなどで、パネルの窓そのものが要るとき用。
    public var panel: NSPanel { popup }

    private let statusItem: NSStatusItem
    private let popup: NSPanel
    private var host: NSHostingView<PanelRoot<Content>>!
    private let buttonTarget = ButtonTarget()
    private var cancellables: Set<AnyCancellable> = []
    private var eventMonitors: [Any] = []
    /// パネル上端の画面座標。中身の高さが変わっても、上端をアイコンの下に保つ。
    private var pinnedTop: CGFloat = 0
    /// いまパネルを出している位置の目印（切り替えで、ほかのアプリに同じ位置を伝える）。
    private var currentAnchor: NSRect = .zero
    /// 起動直後、ほかのアプリの名乗りを待つあいだ（まとめる設定なら、自分のアイコンを出さずに待つ）。
    private var isSettling: Bool
    /// 切り替えで、パネルを引き継いでもらっている相手（相手のパネルが出るまで自分のパネルを残す）。
    private var handoffTarget: String?
    private var handoffFallback: Task<Void, Never>?

    /// - Parameters:
    ///   - appName: 画面に出すアプリの名前（切り替えに出る）。
    ///   - icon: メニューバーのアイコン（テンプレート画像）。
    ///   - content: パネルの中身。引数はパネルを閉じる処理。
    public init(appName: String, icon: NSImage, @ViewBuilder content: @escaping (_ close: @escaping () -> Void) -> Content) {
        coordinator = TsubomiMenuBarCoordinator(appName: appName)
        self.icon = icon
        isSettling = coordinator.preference == .merged
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popup = PopupPanel(
            contentRect: NSRect(x: 0, y: 0, width: PanelMetrics.width, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        let actions = PanelActions()
        host = NSHostingView(rootView: PanelRoot(coordinator: coordinator, actions: actions, content: content(actions.close)))
        actions.closeHandler = { [weak self] in self?.hidePanel() }
        actions.switchHandler = { [weak self] bundleID in self?.switchTo(bundleID) }

        popup.isOpaque = false
        popup.backgroundColor = .clear
        popup.hasShadow = true
        popup.level = .statusBar
        popup.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        popup.isReleasedWhenClosed = false
        popup.hidesOnDeactivate = false
        popup.animationBehavior = .none
        popup.becomesKeyOnlyIfNeeded = true
        // 中身の大きさは SwiftUI に任せず、レイアウトの外で合わせる（resizeToFit）。
        // sizingOptions に任せると、窓のレイアウトの途中で大きさが変わって AppKit の
        // 制約の計算があふれ、画面の多い Mac で起動時に落ちたことがある（TouchRotator）。
        popup.contentView = host

        buttonTarget.action = { [weak self] in self?.statusItemClicked() }
        if let button = statusItem.button {
            button.target = buttonTarget
            button.action = #selector(ButtonTarget.fire)
        }

        coordinator.delegate = self
        coordinator.objectWillChange
            .sink { [weak self] _ in Task { @MainActor [weak self] in self?.resizeToFit() } }
            .store(in: &cancellables)
        updateStatusItem()
        coordinator.start()

        if isSettling {
            // まとめる設定のときは、ほかのアプリの名乗りが届くまで少し待ってからアイコンを決める。
            // 待たないと、起動のたびに自分のアイコンが一瞬出てから消える。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.isSettling = false
                self?.updateStatusItem()
            }
        }
    }

    /// 中身の状態が変わったら、パネルの大きさを合わせ直す。アプリのモデルの objectWillChange を渡す。
    public func redrawWhenChanged<P: Publisher>(_ publisher: P) where P.Failure == Never {
        publisher
            .sink { [weak self] _ in Task { @MainActor [weak self] in self?.resizeToFit() } }
            .store(in: &cancellables)
    }

    // MARK: パネル

    /// 自分のアイコンの下にパネルを開く。まとめているときは 🌸 の下に開く（担当に頼む）。
    public func showPanel() {
        switch coordinator.role {
        case .ownIcon, .flowerHost:
            guard let anchor = statusItemFrame else { return }
            showPanel(below: anchor)
        case .hiddenGuest:
            // 🌸 の位置は担当のアプリしか知らないので、前に出した位置か、画面の右上に出す。
            if currentAnchor != .zero {
                showPanel(below: currentAnchor)
            } else if let screen = NSScreen.main {
                let frame = screen.frame
                showPanel(below: NSRect(x: frame.maxX - 200, y: frame.maxY - 24, width: 30, height: 24))
            }
        }
    }

    public func hidePanel() {
        endHandoff()
        guard popup.isVisible else { return }
        removeMonitors()
        popup.orderOut(nil)
        popup.alphaValue = 1
        coordinator.panelDidChange(isOpen: false)
    }

    public var isPanelVisible: Bool { popup.isVisible }

    private var statusItemFrame: NSRect? {
        statusItem.button?.window?.frame
    }

    private func statusItemClicked() {
        guard let anchor = statusItemFrame else { return }
        switch coordinator.role {
        case .flowerHost:
            coordinator.flowerClicked(anchor: anchor)
        default:
            if popup.isVisible {
                hidePanel()
            } else {
                showPanel(below: anchor)
            }
        }
    }

    private func showPanel(below anchor: NSRect) {
        willShowPanel?()
        currentAnchor = anchor
        pinnedTop = anchor.minY - 4
        let size = host.fittingSize
        var x = anchor.midX - size.width / 2
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) }) ?? NSScreen.main {
            x = min(max(x, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
        }
        popup.setFrame(NSRect(x: x, y: pinnedTop - size.height, width: size.width, height: size.height), display: true)
        let wasVisible = popup.isVisible
        endHandoff()
        popup.alphaValue = 1
        popup.makeKeyAndOrderFront(nil)
        // 切り替えで呼ばれたとき、自分は前面のアプリではない。前のアプリのパネルの上に重ねて出す。
        popup.orderFrontRegardless()
        installMonitors()
        if !wasVisible {
            coordinator.panelDidChange(isOpen: true)
        }
    }

    /// 切り替えでほかのアプリが選ばれた。同じ位置に相手のパネルを出してもらい、
    /// 相手のパネルが出たら（panelState の知らせ）、自分のパネルを薄くしながら消す。
    ///
    /// 先に閉じてから頼むと、相手が出すまでのあいだ（別のアプリなので数十ミリ秒）
    /// 何も出ていない時間ができ、パネルが一瞬消えて見える。重ねてから消せば、ぬるっと切り替わる。
    /// 相手が前の版（この合図を待たない版）でも、相手は panelState を送るので同じように動く。
    private func switchTo(_ bundleID: String) {
        guard bundleID != coordinator.me.bundleID else { return }
        let anchor = currentAnchor
        let isRunning = coordinator.isRunning(bundleID)
        endHandoff()
        handoffTarget = bundleID
        coordinator.open(bundleID, below: anchor)
        // 返事が来なければ閉じる（起動から待つときは長めに）。
        let wait: UInt64 = isRunning ? 1_200_000_000 : 8_000_000_000
        handoffFallback = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: wait)
            guard !Task.isCancelled, let self, self.handoffTarget == bundleID else { return }
            self.fadeOutAndHide()
        }
    }

    private func endHandoff() {
        handoffTarget = nil
        handoffFallback?.cancel()
        handoffFallback = nil
    }

    /// 引き継ぎ相手のパネルが出たあと、自分のパネルを薄くしながら消す。
    private func fadeOutAndHide() {
        endHandoff()
        guard popup.isVisible else { return }
        removeMonitors()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            popup.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.popup.alphaValue < 0.01 else { return }
                self.hidePanel()
            }
        })
    }

    private func resizeToFit() {
        guard popup.isVisible else { return }
        let size = host.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        let frame = popup.frame
        guard abs(size.width - frame.width) > 0.5 || abs(size.height - frame.height) > 0.5 else { return }
        popup.setFrame(NSRect(x: frame.minX, y: pinnedTop - size.height, width: size.width, height: size.height), display: true)
        popup.invalidateShadow()
    }

    // MARK: メニューバーのアイコン

    private func updateStatusItem() {
        switch coordinator.role {
        case .ownIcon:
            statusItem.isVisible = isIconVisible && !isSettling
            statusItem.button?.image = icon
            statusItem.button?.setAccessibilityLabel(coordinator.me.name)
            statusItem.button?.toolTip = nil
        case .flowerHost:
            statusItem.isVisible = true
            statusItem.button?.image = FlowerIcon.image
            statusItem.button?.setAccessibilityLabel(L("tsubomi のアプリ"))
            statusItem.button?.toolTip = L("tsubomi のアプリ")
        case .hiddenGuest:
            statusItem.isVisible = false
        }
    }

    // MARK: パネルの外のクリック・esc

    /// パネルの外を押したら閉じる。自分のアイコン自体のクリックは statusItemClicked に任せる。
    private func installMonitors() {
        removeMonitors()
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            Task { @MainActor [weak self] in self?.hidePanel() }
        }) {
            eventMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] event in
            guard let self else { return event }
            if event.window !== self.popup, event.window !== self.statusItem.button?.window {
                self.hidePanel()
            }
            return event
        }) {
            eventMonitors.append(local)
        }
        if let escape = NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: { [weak self] event in
            if event.keyCode == 53, self?.popup.isVisible == true {
                self?.hidePanel()
                return nil
            }
            return event
        }) {
            eventMonitors.append(escape)
        }
    }

    private func removeMonitors() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors = []
    }
}

extension TsubomiMenuBar: MenuBarCoordinatorDelegate {
    func coordinatorDidChangeRole(_ coordinator: TsubomiMenuBarCoordinator) {
        // アイコンを隠す前に、パネルが自分のアイコンの下に開いていたかを見ておく。
        let openBelowOwnIcon = popup.isVisible && statusItem.isVisible && currentAnchor == statusItemFrame
        isSettling = false
        updateStatusItem()
        if case .hiddenGuest = coordinator.role, openBelowOwnIcon {
            // 自分のアイコンが消えるので、その下に開いていたパネルは閉じる。
            hidePanel()
        }
        Task { @MainActor [weak self] in self?.resizeToFit() }
    }

    func coordinator(_ coordinator: TsubomiMenuBarCoordinator, showPanelBelow anchor: NSRect) {
        showPanel(below: anchor)
    }

    func coordinatorRequestsHide(_ coordinator: TsubomiMenuBarCoordinator) {
        hidePanel()
    }

    func coordinator(_ coordinator: TsubomiMenuBarCoordinator, panelOpenedIn bundleID: String) {
        if handoffTarget == bundleID {
            fadeOutAndHide()
        }
    }
}

/// キーを受け取れる枠なしパネル。枠なしのままだとスイッチが「非アクティブ」の灰色で描かれ、
/// esc も届かない。nonactivating なので、アプリ自体は前に出てこない。
private final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// ステータス項目のボタンの押し先。総称型のクラスは @objc のメソッドを持てないので分けている。
private final class ButtonTarget: NSObject {
    var action: (() -> Void)?
    @objc func fire() { action?() }
}

/// パネルの中身から呼ぶ処理（閉じる・切り替える）。
@MainActor
final class PanelActions {
    var closeHandler: (() -> Void)?
    var switchHandler: ((String) -> Void)?

    lazy var close: () -> Void = { [weak self] in self?.closeHandler?() }
}
