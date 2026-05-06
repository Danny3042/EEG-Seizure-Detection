//
//  SpikeArcEntity.swift
//  EEG-Dashboard-visionOS
//
//  Creates thin cylinder arcs between co-spiking electrode positions
//  and auto-removes them after a short lifetime.

import RealityKit
import SwiftUI

@MainActor
enum SpikeArcEntity {

    // MARK: - Factory

    /// Build a cylinder entity stretching from `start` to `end`.
    static func make(
        from start: SIMD3<Float>,
        to   end:   SIMD3<Float>,
        alert:      Bool = false
    ) -> ModelEntity {
        let vector = end - start
        let length = simd_length(vector)
        guard length > 0.001 else { return ModelEntity() }

        let mesh = MeshResource.generateCylinder(height: length, radius: 0.0006)
        let tint: UIColor = alert
            ? UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.72)
            : UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.58)

        let mat    = UnlitMaterial(color: tint)
        let entity = ModelEntity(mesh: mesh, materials: [mat])

        // Place at midpoint
        entity.position = (start + end) * 0.5

        // Orient the cylinder (default Y-up) to point along `vector`
        let dir = normalize(vector)
        let up  = SIMD3<Float>(0, 1, 0)
        if abs(dot(dir, up)) < 0.9999 {
            let axis  = normalize(cross(up, dir))
            let angle = acos(simd_clamp(dot(up, dir), -1.0, 1.0))
            entity.orientation = simd_quatf(angle: angle, axis: axis)
        }

        return entity
    }

    // MARK: - Lifetime

    /// Remove `entity` from its parent after `duration` seconds.
    static func scheduleRemoval(of entity: ModelEntity, after duration: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            entity.removeFromParent()
        }
    }
}
