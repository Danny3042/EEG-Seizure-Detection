//
//  EEGImmersiveView.swift
//  EEG-Dashboard-visionOS
//
//  Interactive mixed-immersion EEG brain map:
//  • 22 tappable electrode orbs coloured by channel activity
//  • Spike arcs drawn between co-active electrodes
//  • Floating glass detail panel attached to the selected electrode

import SwiftUI
import RealityKit

struct EEGImmersiveView: View {

    @Environment(AppModel.self)   private var appModel
    @Environment(\.openWindow)    private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    // Persisted across SwiftUI re-renders
    @State private var root    = Entity()
    @State private var orbs:   [ModelEntity] = []
    @State private var arcRoot = Entity()

    // MARK: - Body

    var body: some View {
        RealityView { content, attachments in
            // Register custom ECS components once
            ElectrodeEntity.registerComponents()

            // Root entity — centred in the volume's local coordinate space
            let rootEntity = Entity()
            rootEntity.position = [0, 0, 0]
            content.add(rootEntity)

            // Separate child entity used as the arc container so arcs can be
            // added/removed without touching the electrode hierarchy
            let arcs = Entity()
            rootEntity.addChild(arcs)
            arcRoot = arcs

            // Build 22 interactive electrode orbs
            orbs = ElectrodeEntity.buildAll(parent: rootEntity)
            root = rootEntity

            // Attach the detail panel; hidden until an electrode is selected
            if let panel = attachments.entity(for: "detail") {
                panel.isEnabled = false
                rootEntity.addChild(panel)
            }

        } update: { _, attachments in
            updateOrbs()
            updateDetailPanel(attachments)

        } attachments: {
            // Always provide a concrete view so the attachment entity exists;
            // visibility is controlled via `panel.isEnabled` in update.
            Attachment(id: "detail") {
                ElectrodeDetailPanel(channelIndex: appModel.selectedChannel ?? 0)
                    .environment(appModel)
            }
        }
        // ── Spatial tap gesture ───────────────────────────────────────────
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard let comp = value.entity.components[ChannelComponent.self] else { return }
                    // Toggle: tap selected electrode again to deselect
                    appModel.selectedChannel = (appModel.selectedChannel == comp.index)
                        ? nil
                        : comp.index
                }
        )
        // ── Spawn arcs whenever the set of live spikes changes ────────────
        .onChange(of: appModel.liveSpikes) { oldSpikes, newSpikes in
            let newlyFired = newSpikes.subtracting(oldSpikes)
            if !newlyFired.isEmpty, newSpikes.count >= 2 {
                spawnArcs(for: newSpikes)
            }
        }
        // ── Volume control bar ────────────────────────────────────────────
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack(spacing: 20) {
                // Back to dashboard — opens the flat window and closes the volume
                Button {
                    openWindow(id: "main")
                    dismissWindow(id: appModel.immersiveSpaceID)
                } label: {
                    Label("Dashboard", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.borderedProminent)

                Divider().frame(height: 24)

                // Start / stop EEG simulation
                Button(action: { appModel.startSimulation() }) {
                    Label(
                        appModel.isMonitoring ? "Stop" : "Start EEG",
                        systemImage: appModel.isMonitoring ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(appModel.isMonitoring ? .red : .green)

                // Live spike count badge
                if !appModel.liveSpikes.isEmpty {
                    Label("\(appModel.liveSpikes.count) spiking",
                          systemImage: "bolt.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .glassBackgroundEffect()
        }
    }

    // MARK: - Orb update

    private func updateOrbs() {
        let activity = appModel.channelActivity
        let spikes   = appModel.liveSpikes
        let isAlert  = appModel.seizureProbability > 0.7
        let selected = appModel.selectedChannel

        for (i, orb) in orbs.enumerated() {
            guard i < activity.count else { continue }
            let level   = activity[i]
            let spiking = spikes.contains(i)
            let sel     = selected == i

            // Scale: selected > spiking > idle
            let targetScale: Float = sel
                ? 2.2
                : spiking
                    ? 1.4 + level * 0.8
                    : 0.8 + level * 0.4
            orb.scale = SIMD3(repeating: targetScale)

            // Colour
            let tint: UIColor
            if sel {
                // Gold highlight for selected electrode
                tint = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 0.95)
            } else if isAlert && spiking {
                tint = UIColor(red: 1.0, green: 0.15, blue: 0.15,
                               alpha: min(0.85 + CGFloat(level) * 0.15, 1.0))
            } else if spiking {
                tint = UIColor(red: 1.0, green: 0.55, blue: 0.0,
                               alpha: min(0.75 + CGFloat(level) * 0.25, 1.0))
            } else {
                tint = UIColor(red: 0.0, green: 0.8, blue: 1.0,
                               alpha: 0.18 + CGFloat(level) * 0.55)
            }

            var mat = SimpleMaterial()
            mat.color = .init(tint: tint)
            orb.model?.materials = [mat]
        }
    }

    // MARK: - Detail panel update

    private func updateDetailPanel(_ attachments: RealityViewAttachments) {
        guard let panel = attachments.entity(for: "detail") else { return }

        let selected = appModel.selectedChannel
        panel.isEnabled = selected != nil

        guard let idx = selected, idx < ElectrodeEntity.layout.count else { return }

        // Float the panel slightly to the right of the selected electrode
        let electrodePos = ElectrodeEntity.layout[idx].pos
        panel.position = electrodePos + SIMD3<Float>(0.10, 0.02, 0.02)
    }

    // MARK: - Spike arc spawning

    private func spawnArcs(for spikes: Set<Int>) {
        let layout  = ElectrodeEntity.layout
        let isAlert = appModel.seizureProbability > 0.7
        // Limit to 4 electrodes to cap the number of arcs at C(4,2) = 6
        let active  = Array(spikes.filter { $0 < layout.count }).prefix(4)

        for i in active.indices {
            for j in (i + 1)..<active.endIndex {
                let a   = layout[active[i]].pos
                let b   = layout[active[j]].pos
                let arc = SpikeArcEntity.make(from: a, to: b, alert: isAlert)
                arcRoot.addChild(arc)
                SpikeArcEntity.scheduleRemoval(of: arc, after: 1.4)
            }
        }
    }
}

// MARK: - Preview

#Preview(immersionStyle: .mixed) {
    EEGImmersiveView()
        .environment(AppModel())
}
