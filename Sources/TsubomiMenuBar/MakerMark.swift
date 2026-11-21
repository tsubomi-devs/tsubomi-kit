import AppKit
import SwiftUI

/// 設定のサイドバーの下に出す、作り手の印（tsubomi のロゴと ©）。
/// DMG の窓の右下と同じもの。花の画像は .app の Resources/tsubomi-logo.png
/// （Makefile が Resources/dmg/tsubomi-logo.png から入れる）。
public struct MakerMark: View {
    public init() {}

    private static let flower: NSImage? = {
        guard let url = Bundle.main.url(forResource: "tsubomi-logo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    public var body: some View {
        HStack(spacing: 6) {
            if let flower = Self.flower {
                Image(nsImage: flower)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 15, height: 15)
                    .clipShape(RoundedRectangle(cornerRadius: 3.75, style: .continuous))
            }
            Text(verbatim: "© 2026 tsubomi")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
