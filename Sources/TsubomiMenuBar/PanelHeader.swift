import AppKit
import SwiftUI

/// パネルの一番上：アプリのアイコン、名前、状態（色の点と一言）、右にスイッチなど。
///
/// どの tsubomi のアプリでも同じ見た目になるよう、ここで描く（前は各アプリが自分で描いていて、
/// Profilink だけ余白とスイッチの大きさが違っていた）。寸法は TouchRotator のものに合わせた：
/// アイコン 46、間隔 10、名前 14pt 太字、点 7、状態は caption。外側の余白はパネル（12）だけ。
public struct TsubomiPanelHeader<Accessory: View>: View {
    private let name: String
    private let status: String
    private let statusColor: Color
    private let accessory: Accessory

    /// - Parameters:
    ///   - name: アプリの名前（訳さない）。
    ///   - status: 状態の一言（訳したもの）。
    ///   - statusColor: 点の色。動いている = 緑、止まっている = 灰、要対応 = 赤。
    ///   - accessory: 右端に置くもの（スイッチなど）。
    public init(name: String, status: String, statusColor: Color, @ViewBuilder accessory: () -> Accessory) {
        self.name = name
        self.status = status
        self.statusColor = statusColor
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .font(.system(size: 14, weight: .bold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(verbatim: status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            accessory
        }
    }
}

public extension TsubomiPanelHeader where Accessory == EmptyView {
    init(name: String, status: String, statusColor: Color) {
        self.init(name: name, status: status, statusColor: statusColor) { EmptyView() }
    }
}

/// ヘッダーの右端のスイッチ（TouchRotator と同じ大きさ）。下に小さくショートカットを添えられる。
public struct TsubomiHeaderSwitch: View {
    @Binding private var isOn: Bool
    private let shortcut: String?
    private let help: String

    public init(isOn: Binding<Bool>, shortcut: String? = nil, help: String = "") {
        _isOn = isOn
        self.shortcut = shortcut
        self.help = help
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
            if let shortcut {
                Text(verbatim: shortcut)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }
        }
        .help(help)
    }
}
