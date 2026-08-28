import SwiftUI

/// AR映像の上に重ねる情報表示。月の方角・高度・満ち欠け、
/// そして画面外にいる月へ向く方位ガイド矢印を出す。
struct HUDView: View {
    @ObservedObject var model: MoonModel

    private var moon: MoonEphemeris.State? { model.today }

    /// 端末の向きから見た月の相対方位（-180..180°, 0=正面）。
    private var relativeBearing: Double {
        guard let m = moon else { return 0 }
        var d = m.azimuth - model.heading
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    private var moonBelowHorizon: Bool { (moon?.altitude ?? 0) < 0 }

    var body: some View {
        VStack {
            topCard
            Spacer()
            guidance
            Spacer()
            bottomInfo
        }
        .padding()
        .foregroundStyle(KaguyaTheme.ivory)
    }

    private var topCard: some View {
        VStack(spacing: 4) {
            Text("かぐや姫カメラ")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(KaguyaTheme.gold)
            if let m = moon {
                Text(m.phaseNameJa)
                    .font(.system(.title3, design: .serif))
                Text(String(format: "輝面 %.0f%%・%@", m.illumination * 100,
                            m.waxing ? "満ちる" : "欠ける"))
                    .font(.caption)
                    .foregroundStyle(KaguyaTheme.mist)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 18)
        .background(KaguyaTheme.ink.opacity(0.55), in: Capsule())
    }

    @ViewBuilder private var guidance: some View {
        if moonBelowHorizon {
            VStack(spacing: 6) {
                Image(systemName: "moon.zzz")
                Text("今は月が地平線の下です")
                    .font(.system(.subheadline, design: .serif))
                Text("計算上の方角・満ち欠けを表示中")
                    .font(.caption2).foregroundStyle(KaguyaTheme.mist)
            }
            .padding().background(KaguyaTheme.ink.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        } else if abs(relativeBearing) > 25 {
            VStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 44, weight: .light))
                    .rotationEffect(.degrees(relativeBearing))
                    .foregroundStyle(KaguyaTheme.gold)
                Text(relativeBearing > 0 ? "右へ向けて" : "左へ向けて")
                    .font(.system(.subheadline, design: .serif))
            }
            .padding().background(KaguyaTheme.ink.opacity(0.4), in: Circle())
        }
    }

    private var bottomInfo: some View {
        HStack(spacing: 24) {
            if let m = moon {
                infoItem("方角", compass(m.azimuth))
                infoItem("方位角", String(format: "%.0f°", m.azimuth))
                infoItem("高度", String(format: "%.0f°", m.altitude))
                infoItem("距離", String(format: "%.0f km", m.distanceKm))
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .background(KaguyaTheme.ink.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .top) {
            if !model.hasLocation {
                Text("現在地を取得中…（暫定：東京）")
                    .font(.caption2).foregroundStyle(KaguyaTheme.mist)
                    .offset(y: -22)
            }
        }
    }

    private func infoItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(KaguyaTheme.mist)
            Text(value).font(.system(.subheadline, design: .serif))
        }
    }

    private func compass(_ az: Double) -> String {
        let dirs = ["北", "北東", "東", "南東", "南", "南西", "西", "北西"]
        let i = Int(((az + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return dirs[max(0, min(7, i))]
    }
}
