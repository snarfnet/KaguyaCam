import UIKit

/// 輝面比と満ち欠けの向きから月の絵（満ち欠けディスク）を描く。
/// AR空間のプレーンにも、2DのHUDアイコンにも同じ絵を使う。
enum MoonRenderer {

    /// 月ディスクの画像を生成する。
    /// - k: 輝面比（0=新月, 1=満月）
    /// - waxing: true=満ちる（右側が光る）, false=欠ける（左側が光る）
    /// - size: 出力画像の一辺（px）
    /// - glow: 外周のほのかな光を描くか
    static func image(illumination k: Double, waxing: Bool, size: CGFloat, glow: Bool = true) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let center = CGPoint(x: size / 2, y: size / 2)
            let r = size * 0.40

            let lit = UIColor(red: 0.98, green: 0.96, blue: 0.86, alpha: 1.0)   // 象牙
            let dark = UIColor(red: 0.14, green: 0.16, blue: 0.26, alpha: 1.0)  // 深藍

            if glow {
                let glowColors = [
                    UIColor(red: 0.95, green: 0.93, blue: 0.78, alpha: 0.55).cgColor,
                    UIColor(red: 0.95, green: 0.93, blue: 0.78, alpha: 0.0).cgColor
                ] as CFArray
                if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: glowColors, locations: [0, 1]) {
                    c.drawRadialGradient(grad, startCenter: center, startRadius: r * 0.85,
                                         endCenter: center, endRadius: r * 1.45,
                                         options: [])
                }
            }

            // 暗い側（地球照っぽく僅かに見せる）
            c.setFillColor(dark.cgColor)
            c.addArc(center: center, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            c.fillPath()

            // 明るい側：円板と明暗境界(ターミネーター)楕円の交わりをサンプリングで塗る
            let kk = max(0.0, min(1.0, k))
            let path = UIBezierPath()
            let steps = 180
            // 右半分/左半分の輪郭 → ターミネーター楕円で戻る閉曲線
            var outline: [CGPoint] = []
            for i in 0...steps {
                let t = -Double.pi / 2 + Double.pi * Double(i) / Double(steps) // -90°..90°（右側の弧）
                let y = center.y - r * CGFloat(sin(t))
                let xd = r * CGFloat(cos(t)) // 円板の半幅
                if waxing {
                    outline.append(CGPoint(x: center.x + xd, y: y))
                } else {
                    outline.append(CGPoint(x: center.x - xd, y: y))
                }
            }
            // ターミネーター：半幅 xd に係数(1-2k)を掛けた楕円
            let f = CGFloat(1.0 - 2.0 * kk)
            for i in stride(from: steps, through: 0, by: -1) {
                let t = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
                let y = center.y - r * CGFloat(sin(t))
                let xt = r * CGFloat(cos(t)) * f
                if waxing {
                    outline.append(CGPoint(x: center.x + xt, y: y))
                } else {
                    outline.append(CGPoint(x: center.x - xt, y: y))
                }
            }
            if let first = outline.first {
                path.move(to: first)
                for p in outline.dropFirst() { path.addLine(to: p) }
                path.close()
            }
            lit.setFill()
            path.fill()

            // ふちの締め
            c.setStrokeColor(UIColor(white: 1.0, alpha: 0.15).cgColor)
            c.setLineWidth(size * 0.006)
            c.addArc(center: center, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            c.strokePath()
        }
    }
}
