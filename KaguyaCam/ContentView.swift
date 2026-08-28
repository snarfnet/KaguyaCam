import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var model = MoonModel()
    @State private var showInfo = false

    var body: some View {
        if ScreenshotMode.isActive {
            SkyDemoView(screen: ScreenshotMode.value)
        } else {
            liveView
        }
    }

    private var liveView: some View {
        ZStack {
            if ARWorldTrackingConfiguration.isSupported {
                ARSkyView(model: model).ignoresSafeArea()
            } else {
                unsupported
            }
            HUDView(model: model)
            VStack {
                HStack {
                    Spacer()
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundStyle(KaguyaTheme.ivory)
                            .padding(10)
                            .background(KaguyaTheme.ink.opacity(0.5), in: Circle())
                    }
                }
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showInfo) { InfoView(model: model) }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .statusBarHidden()
    }

    private var unsupported: some View {
        ZStack {
            KaguyaTheme.ink.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 44)).foregroundStyle(KaguyaTheme.gold)
                Text("この端末はARに対応していません")
                    .font(.system(.headline, design: .serif))
                Text("方角と満ち欠けの計算結果のみ表示します")
                    .font(.caption).foregroundStyle(KaguyaTheme.mist)
            }
            .foregroundStyle(KaguyaTheme.ivory)
        }
    }
}
