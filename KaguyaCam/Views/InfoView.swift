import SwiftUI

/// 使い方・原理・満ち欠けの3日比較を出す情報画面。
struct InfoView: View {
    @ObservedObject var model: MoonModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    threeDayStrip
                    section("使い方", [
                        "夜空にカメラを向けると、いまの月の方角に月が浮かびます。",
                        "月の両隣に、昨夜と明晩の満ち欠けを並べて表示します。",
                        "画面の矢印が、月のいる方角へ案内します。"
                    ])
                    section("仕組み", [
                        "現在地と時刻から、天文計算で月の方角・高度・満ち欠けを求めています。",
                        "曇りや昼でも「いま月はどこか」を計算で表示できます。",
                        "方位は端末のコンパスに依存します。8の字を描いて補正すると精度が上がります。"
                    ])
                    Text("月の方角・満ち欠けは天文計算による目安です。")
                        .font(.caption).foregroundStyle(KaguyaTheme.mist)
                }
                .padding()
            }
            .background(KaguyaTheme.ink.ignoresSafeArea())
            .foregroundStyle(KaguyaTheme.ivory)
            .navigationTitle("かぐや姫カメラ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }.foregroundStyle(KaguyaTheme.gold)
                }
            }
        }
    }

    private var threeDayStrip: some View {
        HStack {
            dayCell("昨夜", model.yesterday)
            dayCell("今夜", model.today, highlight: true)
            dayCell("明晩", model.tomorrow)
        }
    }

    private func dayCell(_ label: String, _ state: MoonEphemeris.State?, highlight: Bool = false) -> some View {
        VStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(KaguyaTheme.mist)
            if let s = state {
                Image(uiImage: MoonRenderer.image(illumination: s.illumination,
                                                  waxing: s.waxing,
                                                  size: 160))
                    .resizable().scaledToFit()
                    .frame(width: highlight ? 84 : 64, height: highlight ? 84 : 64)
                Text(s.phaseNameJa).font(.caption2)
                Text(String(format: "%.0f%%", s.illumination * 100))
                    .font(.caption2).foregroundStyle(KaguyaTheme.mist)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(highlight ? KaguyaTheme.inkSoft : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12))
    }

    private func section(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(KaguyaTheme.gold)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text("・")
                    Text(line)
                }.font(.system(.subheadline, design: .serif))
            }
        }
    }
}
