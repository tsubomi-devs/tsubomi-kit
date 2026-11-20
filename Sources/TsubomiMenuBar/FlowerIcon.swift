import AppKit

/// まとめたときにメニューバーに出す 🌸（tsubomi の花の形。白黒のテンプレート画像）。
///
/// tsubomi のロゴと同じ、少しねじれた 5 枚の花びら。明るい／暗いメニューバーや
/// 押したときの色は、テンプレート画像なので macOS が付ける。
public enum FlowerIcon {
    /// 描く大きさ（pt）。メニューバーの高さ（約 22pt）に合わせる。
    private static let side: CGFloat = 22

    @MainActor
    public static let image: NSImage = {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let petalLength = side * 0.40
            let petalWidth = side * 0.23
            for index in 0..<5 {
                let angle = CGFloat(index) * 72
                let transform = NSAffineTransform()
                transform.translateX(by: center.x, yBy: center.y)
                transform.rotate(byDegrees: angle)
                // 花びらを中心から少しずらし、少し傾けて、ねじれた花にする。
                transform.translateX(by: side * 0.04, yBy: side * 0.19)
                transform.rotate(byDegrees: -22)
                let petal = NSBezierPath(ovalIn: NSRect(
                    x: -petalWidth / 2,
                    y: -petalLength / 2,
                    width: petalWidth,
                    height: petalLength
                ))
                petal.transform(using: transform as AffineTransform)
                petal.fill()
            }
            // 真ん中を抜いて、花らしく見せる。
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: NSRect(x: center.x - side * 0.08, y: center.y - side * 0.08, width: side * 0.16, height: side * 0.16)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "tsubomi"
        return image
    }()
}
