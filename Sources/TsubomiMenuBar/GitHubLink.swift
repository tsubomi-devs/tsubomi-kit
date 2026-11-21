import AppKit
import SwiftUI

/// GitHub のマークだけのリンク（設定 › 情報 の右上。押すとこのバージョンのリリースノート）。
/// 何のリンクかはマウスを乗せると出る（help）。
/// マークは .app の Resources/github-mark.png（Makefile が Resources/ から入れる）。
/// テンプレート画像にして、リンクの文字と同じ色で描く。
public struct GitHubLink: View {
    let title: LocalizedStringKey
    let destination: URL
    var size: CGFloat = 22

    public init(title: LocalizedStringKey, destination: URL, size: CGFloat = 22) {
        self.title = title
        self.destination = destination
        self.size = size
    }

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "github-mark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }()

    public var body: some View {
        Link(destination: destination) {
            if let mark = Self.mark {
                Image(nsImage: mark)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .foregroundColor(.secondary)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}
