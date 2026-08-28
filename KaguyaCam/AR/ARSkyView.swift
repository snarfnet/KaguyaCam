import SwiftUI
import SceneKit
import ARKit
import UIKit

/// カメラ映像の上に、計算した方角・高度で月を重ねて表示するARビュー。
/// worldAlignment = .gravityAndHeading により、ワールド座標が
/// 「y=上, x=東, -z=真北」に揃う。ここへ月を方位角・高度で配置する。
struct ARSkyView: UIViewRepresentable {
    @ObservedObject var model: MoonModel

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        context.coordinator.sceneView = view

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        view.session.run(config)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.update(today: model.today,
                                   yesterday: model.yesterday,
                                   tomorrow: model.tomorrow)
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator {
        weak var sceneView: ARSCNView?
        private var placed = false

        /// 方位角(北=0 東=90)・高度(°) → ワールド座標のベクトル。
        private func skyVector(azDeg: Double, altDeg: Double, radius: Float) -> SCNVector3 {
            let az = azDeg * .pi / 180.0
            let alt = altDeg * .pi / 180.0
            let x = Float(sin(az) * cos(alt)) * radius       // 東
            let y = Float(sin(alt)) * radius                 // 上
            let z = -Float(cos(az) * cos(alt)) * radius      // 北 = -z
            return SCNVector3(x, y, z)
        }

        private func moonNode(state: MoonEphemeris.State, diameter: CGFloat, name: String) -> SCNNode {
            let img = MoonRenderer.image(illumination: state.illumination,
                                         waxing: state.waxing,
                                         size: 512)
            let plane = SCNPlane(width: diameter, height: diameter)
            let mat = SCNMaterial()
            mat.diffuse.contents = img
            mat.isDoubleSided = true
            mat.lightingModel = .constant
            mat.blendMode = .alpha
            plane.firstMaterial = mat
            let node = SCNNode(geometry: plane)
            node.name = name
            node.constraints = [SCNBillboardConstraint()] // 常にカメラを向く
            return node
        }

        func update(today: MoonEphemeris.State?,
                    yesterday: MoonEphemeris.State?,
                    tomorrow: MoonEphemeris.State?) {
            guard let scene = sceneView?.scene, let now = today else { return }
            // 位置は毎回作り直さず、既存ノードを更新する
            scene.rootNode.childNode(withName: "moon_today", recursively: false)?.removeFromParentNode()
            scene.rootNode.childNode(withName: "moon_prev", recursively: false)?.removeFromParentNode()
            scene.rootNode.childNode(withName: "moon_next", recursively: false)?.removeFromParentNode()

            let R: Float = 30                 // 月ノードまでの距離(m)
            let offset = 7.0                  // 両隣を並べる方位オフセット(°)

            let center = moonNode(state: now, diameter: 6, name: "moon_today")
            center.position = skyVector(azDeg: now.azimuth, altDeg: now.altitude, radius: R)
            scene.rootNode.addChildNode(center)

            if let prev = yesterday {
                let n = moonNode(state: prev, diameter: 3.4, name: "moon_prev")
                n.position = skyVector(azDeg: now.azimuth - offset, altDeg: now.altitude, radius: R)
                scene.rootNode.addChildNode(n)
                addLabel("昨夜", to: n, y: -2.6)
            }
            if let next = tomorrow {
                let n = moonNode(state: next, diameter: 3.4, name: "moon_next")
                n.position = skyVector(azDeg: now.azimuth + offset, altDeg: now.altitude, radius: R)
                scene.rootNode.addChildNode(n)
                addLabel("明晩", to: n, y: -2.6)
            }
            placed = true
        }

        private func addLabel(_ text: String, to node: SCNNode, y: Float) {
            let t = SCNText(string: text, extrusionDepth: 0.2)
            t.font = .systemFont(ofSize: 3)
            t.firstMaterial?.diffuse.contents = UIColor(white: 0.9, alpha: 0.9)
            t.firstMaterial?.lightingModel = .constant
            let label = SCNNode(geometry: t)
            label.scale = SCNVector3(0.28, 0.28, 0.28)
            label.position = SCNVector3(-0.9, y, 0)
            label.constraints = [SCNBillboardConstraint()]
            node.addChildNode(label)
        }
    }
}
