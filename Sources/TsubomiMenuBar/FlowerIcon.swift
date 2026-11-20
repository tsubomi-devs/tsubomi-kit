import AppKit

/// まとめたときにメニューバーに出す 🌸（白黒のテンプレート画像）。
///
/// tsubomi のロゴ画像（各アプリの Resources/tsubomi-logo.png。設定画面の下の © にも
/// 使っているもの）から、白い花の部分だけを抜き出して使う。ピンクの地は透明になるので、
/// メニューバーの絵はロゴの花そのもの。Profilink の MenuBarIcon と同じ作り方。
/// 明るい／暗いメニューバーや押したときの色は、テンプレート画像なので macOS が付ける。
///
/// ロゴ画像が見つからないとき（`swift run` で動かしたときなど）は、線で描いた花を使う。
public enum FlowerIcon {
    /// 描く大きさ（pt）。メニューバーの高さ（約 22pt）に合わせる。
    private static let side: CGFloat = 22

    @MainActor
    public static let image: NSImage = {
        let image = extractLogoFlower() ?? drawnFlower()
        image.isTemplate = true
        image.accessibilityDescription = "tsubomi"
        return image
    }()

    // MARK: ロゴ画像から花を抜き出す

    @MainActor
    private static func extractLogoFlower() -> NSImage? {
        guard let logo = Bundle.main.image(forResource: "tsubomi-logo") else { return nil }

        // 1. ロゴ全体を大きめに描き、白に近い画素（花）だけを残した型を作る。
        let pixels = 256
        guard let rep = bitmap(pixels) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        logo.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
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
        // 白い花がほとんど無い（想定外の画像）なら、抜き出し失敗として線で描いた花にする。
        guard opaquePixels > 1500, maxX > minX, maxY > minY, let full = rep.cgImage else { return nil }

        // 2. 花の部分だけを切り出し、メニューバーの枠に（縦横比はそのまま）収める。
        let box = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = full.cropping(to: box) else { return nil }
        let scale = 4
        let canvas = Int(side) * scale
        guard let out = bitmap(canvas) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        NSGraphicsContext.current?.imageInterpolation = .high
        // ほかのアイコンと同じくらいの大きさに見えるよう、少しだけ余白を取る。
        let padding = CGFloat(canvas) * 0.06
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
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    }

    // MARK: 代わりの絵（ロゴ画像の無い起動用）

    private static func drawnFlower() -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let petalLength = side * 0.40
            let petalWidth = side * 0.23
            for index in 0..<5 {
                let transform = NSAffineTransform()
                transform.translateX(by: center.x, yBy: center.y)
                transform.rotate(byDegrees: CGFloat(index) * 72)
                transform.translateX(by: side * 0.04, yBy: side * 0.19)
                transform.rotate(byDegrees: -22)
                let petal = NSBezierPath(ovalIn: NSRect(x: -petalWidth / 2, y: -petalLength / 2, width: petalWidth, height: petalLength))
                petal.transform(using: transform as AffineTransform)
                petal.fill()
            }
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: NSRect(x: center.x - side * 0.08, y: center.y - side * 0.08, width: side * 0.16, height: side * 0.16)).fill()
            return true
        }
    }
}
