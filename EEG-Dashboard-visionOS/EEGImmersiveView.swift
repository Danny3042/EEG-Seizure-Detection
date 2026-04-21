import SwiftUI
import RealityKit

struct EEGImmersiveView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var root = Entity()
    @State private var orbs: [ModelEntity] = []

    var body: some View {
        RealityView { content in
            let rootEntity = Entity()
            rootEntity.position = [0, 1.5, -0.8]
            content.add(rootEntity)
            
            let electrodeOrbs = ElectrodeEntity.buildAll(parent: rootEntity)
            root = rootEntity
            orbs = electrodeOrbs
        } update: { content in
            let activity = appModel.channelActivity
            let isAlert = appModel.seizureProbability > 0.7
            for (i, orb) in orbs.enumerated() {
                guard i < activity.count else { continue }
                let level = activity[i]
                orb.scale = SIMD3(repeating: 0.8 + level * 1.4)
                var mat = SimpleMaterial()
                if isAlert {
                    let alpha = 0.4 + level * 0.6
                    mat.color = .init(tint: UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: CGFloat(alpha)))
                } else {
                    let alpha = 0.2 + level * 0.5
                    mat.color = .init(tint: UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: CGFloat(alpha)))
                }
                orb.model?.materials = [mat]
            }
        }
    }
}
