import SwiftUI

/// スクショ用（およびAR非対応端末用）の夜空デモ画面。
/// 実アプリと同じ MoonRenderer で月を描き、深藍の夜空に重ねる。
struct SkyDemoView: View {
    /// 撮影シーン番号（"1"〜"3"）。nil のときは既定=1。
    var screen: String? = "1"

    private struct Scene {
        var yesterday: Double
        var today: Double
        var tomorrow: Double
        var waxing: Bool
        var title: String
        var caption: String
        var compass: String
        var altitude: Int
    }

    private var scene: Scene {
        switch screen {
        case "2":
            return Scene(yesterday: 0.72, today: 0.83, tomorrow: 0.92, waxing: true,
                         title: "方角も、満ち欠けも。",
                         caption: "曇りでも昼でも、今の月がわかる",
                         compass: "南南東", altitude: 41)
        case "3":
            return Scene(yesterday: 0.20, today: 0.30, tomorrow: 0.41, waxing: true,
                         title: "昨日・今日・明日を並べて。",
                         caption: "月の満ち欠けが、ひと目で",
                         compass: "南西", altitude: 26)
        default:
            return Scene(yesterday: 0.19, today: 0.28, tomorrow: 0.38, waxing: true,
                         title: "夜空にかざすと、今夜の月。",
                         caption: "月の方角に、月が浮かぶ",
                         compass: "南東", altitude: 34)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                nightSky
                stars(in: geo.size)
                bamboo(in: geo.size)

                VStack(spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.10)
                    Text("かぐや姫カメラ")
                        .font(.system(size: w * 0.055, weight: .semibold, design: .serif))
                        .foregroundStyle(KaguyaTheme.gold)
                    Text(scene.title)
                        .font(.system(size: w * 0.072, weight: .bold, design: .serif))
                        .foregroundStyle(KaguyaTheme.ivory)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .padding(.horizontal, 20)

                    Spacer()
                    moons(width: w)
                    Spacer()

                    infoChip(width: w)
                    Text(scene.caption)
                        .font(.system(size: w * 0.042, design: .serif))
                        .foregroundStyle(KaguyaTheme.mist)
                        .padding(.top, 14)
                    Spacer().frame(height: geo.size.height * 0.09)
                }
                .padding(.horizontal, 16)
            }
        }
        .ignoresSafeArea()
    }

    private var nightSky: some View {
        LinearGradient(colors: [
            Color(red: 0.05, green: 0.07, blue: 0.16),
            Color(red: 0.10, green: 0.13, blue: 0.26),
            Color(red: 0.16, green: 0.14, blue: 0.24)
        ], startPoint: .top, endPoint: .bottom)
    }

    private func stars(in size: CGSize) -> some View {
        Canvas { ctx, sz in
            var rng = SeededRNG(seed: 42)
            for _ in 0..<90 {
                let x = Double.random(in: 0...sz.width, using: &rng)
                let y = Double.random(in: 0...(sz.height * 0.7), using: &rng)
                let r = Double.random(in: 0.6...2.0, using: &rng)
                let op = Double.random(in: 0.25...0.9, using: &rng)
                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect),
                         with: .color(KaguyaTheme.ivory.opacity(op)))
            }
        }
    }

    private func bamboo(in size: CGSize) -> some View {
        Canvas { ctx, sz in
            let color = GraphicsContext.Shading.color(Color(red: 0.06, green: 0.10, blue: 0.12).opacity(0.9))
            for bx in [sz.width * 0.12, sz.width * 0.86] {
                var p = Path()
                p.addRect(CGRect(x: bx, y: sz.height * 0.55, width: sz.width * 0.018, height: sz.height * 0.45))
                ctx.fill(p, with: color)
            }
        }
    }

    private func moons(width w: CGFloat) -> some View {
        HStack(alignment: .center, spacing: w * 0.05) {
            sideMoon(scene.yesterday, "昨夜", w: w)
            VStack(spacing: 8) {
                Image(uiImage: MoonRenderer.image(illumination: scene.today,
                                                  waxing: scene.waxing, size: 640))
                    .resizable().scaledToFit()
                    .frame(width: w * 0.40, height: w * 0.40)
                Text("今夜").font(.system(size: w * 0.038, design: .serif))
                    .foregroundStyle(KaguyaTheme.ivory)
            }
            sideMoon(scene.tomorrow, "明晩", w: w)
        }
    }

    private func sideMoon(_ k: Double, _ label: String, w: CGFloat) -> some View {
        VStack(spacing: 6) {
            Image(uiImage: MoonRenderer.image(illumination: k, waxing: scene.waxing, size: 400))
                .resizable().scaledToFit()
                .frame(width: w * 0.20, height: w * 0.20)
                .opacity(0.92)
            Text(label).font(.system(size: w * 0.032, design: .serif))
                .foregroundStyle(KaguyaTheme.mist)
        }
    }

    private func infoChip(width w: CGFloat) -> some View {
        HStack(spacing: w * 0.06) {
            chipItem("方角", scene.compass, w: w)
            chipItem("高度", "\(scene.altitude)°", w: w)
            chipItem("輝面", "\(Int(scene.today * 100))%", w: w)
        }
        .padding(.vertical, w * 0.03).padding(.horizontal, w * 0.05)
        .background(KaguyaTheme.ink.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    private func chipItem(_ t: String, _ v: String, w: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(t).font(.system(size: w * 0.030)).foregroundStyle(KaguyaTheme.mist)
            Text(v).font(.system(size: w * 0.045, design: .serif)).foregroundStyle(KaguyaTheme.ivory)
        }
    }
}

/// 決定論的な星の配置に使う簡易乱数。
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 2862933555777941757 &+ 3037000493 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
