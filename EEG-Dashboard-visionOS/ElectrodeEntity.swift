//
//  ElectrodeEntity.swift
//  EEG-Dashboard-visionOS
//

import RealityKit
import SwiftUI

// MARK: - Custom ECS component

/// Carries the electrode channel index so tap gestures can identify which orb was hit.
struct ChannelComponent: Component {
    var index: Int
    var name:  String
}

// MARK: - ElectrodeEntity builder

struct ElectrodeEntity {

    // Standard 10-20 positions in metres, centred at origin
    static let layout: [(name: String, pos: SIMD3<Float>)] = [
        ("Fp1", [-0.15,  0.25, -0.10]), ("Fp2", [ 0.15,  0.25, -0.10]),
        ("F7",  [-0.25,  0.15, -0.05]), ("F3",  [-0.12,  0.18,  0.00]),
        ("Fz",  [ 0.00,  0.20,  0.00]), ("F4",  [ 0.12,  0.18,  0.00]),
        ("F8",  [ 0.25,  0.15, -0.05]), ("T7",  [-0.30,  0.00,  0.05]),
        ("T8",  [ 0.30,  0.00,  0.05]), ("C3",  [-0.15,  0.10,  0.10]),
        ("Cz",  [ 0.00,  0.15,  0.10]), ("C4",  [ 0.15,  0.10,  0.10]),
        ("P7",  [-0.25, -0.05,  0.15]), ("P3",  [-0.12,  0.00,  0.18]),
        ("Pz",  [ 0.00,  0.05,  0.18]), ("P4",  [ 0.12,  0.00,  0.18]),
        ("P8",  [ 0.25, -0.05,  0.15]), ("O1",  [-0.12, -0.15,  0.20]),
        ("O2",  [ 0.12, -0.15,  0.20]), ("FC3", [-0.12,  0.14,  0.05]),
        ("FC4", [ 0.12,  0.14,  0.05]), ("CP3", [-0.12,  0.05,  0.14]),
    ]

    /// Register custom components once at app start.
    static func registerComponents() {
        ChannelComponent.registerComponent()
    }

    /// Build all 22 interactive electrode orbs and an anatomical brain reference.
    /// Returns the `ModelEntity` for each orb so `EEGImmersiveView` can update
    /// materials each frame.
    static func buildAll(parent: Entity) -> [ModelEntity] {
        var orbs: [ModelEntity] = []

        buildBrainReference(parent: parent)

        // ── Electrode orbs ────────────────────────────────────────────────
        for (idx, electrode) in layout.enumerated() {
            let container = Entity()
            container.position = electrode.pos

            // Glow sphere — material updated per-frame by EEGImmersiveView
            let mesh = MeshResource.generateSphere(radius: 0.012)
            var mat  = SimpleMaterial()
            mat.color = .init(tint: UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.3))
            let orb  = ModelEntity(mesh: mesh, materials: [mat])

            // ── Interactive components ─────────────────────────────────────
            // CollisionComponent enables spatial hit-testing
            orb.components.set(CollisionComponent(
                shapes: [.generateSphere(radius: 0.022)],
                mode:   .default,
                filter: .default
            ))
            // InputTargetComponent makes the entity a valid gesture target
            orb.components.set(InputTargetComponent(allowedInputTypes: .all))
            // HoverEffectComponent provides the system look-at highlight
            orb.components.set(HoverEffectComponent())
            // ChannelComponent carries the channel identity
            orb.components.set(ChannelComponent(index: idx, name: electrode.name))

            container.addChild(orb)

            // ── Text label ────────────────────────────────────────────────
            let labelMesh = MeshResource.generateText(
                electrode.name,
                extrusionDepth: 0.001,
                font:           .systemFont(ofSize: 0.006),
                containerFrame: .zero,
                alignment:      .center,
                lineBreakMode:  .byCharWrapping
            )
            let label = ModelEntity(
                mesh:      labelMesh,
                materials: [UnlitMaterial(color: UIColor(white: 1.0, alpha: 0.65))]
            )
            label.position = [0, 0.020, 0]
            container.addChild(label)

            parent.addChild(container)
            orbs.append(orb)
        }

        return orbs
    }

    // MARK: - Brain reference geometry

    /// Builds a multi-sphere anatomical proxy: outer cortex + four lobe regions.
    private static func buildBrainReference(parent: Entity) {
        // ── Outer cortex ─────────────────────────────────────────────────
        // Semi-transparent sphere representing the skull/scalp boundary
        let cortexMesh = MeshResource.generateSphere(radius: 0.22)
        var cortexMat  = SimpleMaterial()
        cortexMat.color     = .init(tint: UIColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 0.07))
        cortexMat.roughness = .float(0.9)
        cortexMat.metallic  = .float(0)
        parent.addChild(ModelEntity(mesh: cortexMesh, materials: [cortexMat]))

        // Thin outer shell for a subtle halo effect
        let shellMesh = MeshResource.generateSphere(radius: 0.228)
        let shellMat  = UnlitMaterial(color: UIColor(white: 0.9, alpha: 0.015))
        parent.addChild(ModelEntity(mesh: shellMesh, materials: [shellMat]))

        // ── Frontal lobe ─────────────────────────────────────────────────
        addLobeSphere(parent: parent,
                      radius: 0.13, position: SIMD3( 0.00,  0.06, -0.11),
                      color: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.06))

        // ── Temporal lobes (bilateral) ────────────────────────────────────
        addLobeSphere(parent: parent,
                      radius: 0.10, position: SIMD3(-0.19, -0.02,  0.02),
                      color: UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 0.055))
        addLobeSphere(parent: parent,
                      radius: 0.10, position: SIMD3( 0.19, -0.02,  0.02),
                      color: UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 0.055))

        // ── Parietal lobe ─────────────────────────────────────────────────
        addLobeSphere(parent: parent,
                      radius: 0.11, position: SIMD3( 0.00,  0.08,  0.10),
                      color: UIColor(red: 0.2, green: 0.9, blue: 0.6, alpha: 0.05))

        // ── Occipital lobe ────────────────────────────────────────────────
        addLobeSphere(parent: parent,
                      radius: 0.09, position: SIMD3( 0.00, -0.05,  0.18),
                      color: UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 0.055))
    }

    private static func addLobeSphere(parent: Entity,
                                       radius: Float,
                                       position: SIMD3<Float>,
                                       color: UIColor) {
        let mesh    = MeshResource.generateSphere(radius: radius)
        var mat     = SimpleMaterial()
        mat.color   = .init(tint: color)
        mat.roughness = .float(1.0)
        mat.metallic  = .float(0)
        let entity  = ModelEntity(mesh: mesh, materials: [mat])
        entity.position = position
        parent.addChild(entity)
    }
}
