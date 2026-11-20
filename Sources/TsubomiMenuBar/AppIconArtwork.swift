import AppKit

/// メニューバーのアイコン（白黒のテンプレート画像）を、アプリのアイコンの白い線画から作る。
///
/// tsubomi のアプリのアイコンは、ターコイズ→青の地に白い線画という同じ作りなので、白に近い画素を
/// 不透明、色の付いた地を透明にすれば、メニューバーの絵がアプリのアイコンの絵そのものになる。
/// Profilink・TouchRotator の MenuBarIcon と同じやり方を、新しいアプリでも使えるようにしたもの。
/// アイコンの無い開発中の起動（swift run）では、`fallbackSymbol` の SF Symbols を使う。
public enum TsubomiMenuBarIcon {
    /// 描く大きさ（pt）。macOS 26 のメニューバーの高さ（約 22pt）に合わせる。
    public static let side: CGFloat = 22

    @MainActor
    public static func fromAppIcon(fallbackSymbol: String, accessibilityDescription: String) -> NSImage {
        let image: NSImage
        if let artwork = extractArtwork() {
            image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
                artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                             respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
                return true
            }
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            image = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: accessibilityDescription)?
                .withSymbolConfiguration(config) ?? NSImage(size: NSSize(width: 18, height: 18))
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    @MainActor
    private static func extractArtwork() -> NSImage? {
        guard let icon = Bundle.main.image(forResource: "AppIcon") else { return nil }

        // 1. アイコン全体を大きめに描き、白に近い画素（線画）だけを残した型を作る。
        let pixels = 256
        guard let rep = bitmap(pixels) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()

        var minX = pixels, minY = pixels, maxX = -1, maxY = -1
        var opaquePixels = 0
        for y in 0..<pixels {
            for x in 0..<pixels {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let minComponent = min(color.redComponent, min(color.greenComponent, color.blueComponent))
                let whiteness = max(0, min(1, (minComponent - 0.55) / 0.3))
                let alpha = whiteness * color.alphaComponent
                if alpha > 0.1 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
                if alpha > 0.5 { opaquePixels += 1 }
                rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: alpha), atX: x, y: y)
            }
        }
        // 白い線画がほとんど無い（想定外のアイコン）なら、抜き出し失敗として代わりの絵にする。
        guard opaquePixels > 150, maxX > minX, maxY > minY, let full = rep.cgImage else { return nil }

        // 2. 線画の部分だけを切り出し、枠いっぱいに（縦横比はそのまま）収める。
        //    アイコンの余白ごと縮めると、まわりのアイコンより小さく見えるため。
        let box = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = full.cropping(to: box) else { return nil }
        let scale = 4
        let canvas = Int(side) * scale
        guard let out = bitmap(canvas) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        NSGraphicsContext.current?.imageInterpolation = .high
        let padding = CGFloat(scale) * 0.5
        let fit = min((CGFloat(canvas) - padding * 2) / box.width, (CGFloat(canvas) - padding * 2) / box.height)
        let drawn = CGSize(width: box.width * fit, height: box.height * fit)
        NSImage(cgImage: cropped, size: box.size).draw(in: NSRect(
            x: (CGFloat(canvas) - drawn.width) / 2,
            y: (CGFloat(canvas) - drawn.height) / 2,
            width: drawn.width,
            height: drawn.height
        ))
        NSGraphicsContext.restoreGraphicsState()

        out.size = NSSize(width: side, height: side)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.addRepresentation(out)
        return image
    }

    private static func bitmap(_ pixels: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )
    }
}
