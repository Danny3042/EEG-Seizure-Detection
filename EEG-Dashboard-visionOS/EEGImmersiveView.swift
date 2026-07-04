//
//  EEGImmersiveView.swift
//  EEG-Dashboard-visionOS
//
//  Interactive mixed-immersion EEG brain map:
//  • 22 tappable electrode orbs coloured by channel activity
//  • Spike arcs drawn between co-active electrodes
//  • Floating glass detail panel attached to the selected electrode
//  • TimelineView-driven pulse animation when seizure risk is high

import SwiftUI
import RealityKit

struct EEGImmersiveView: View {

    @Environment(AppModel.self)    private var appModel
    @Environment(\.openWindow)    private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var root    = Entity()
    @State private var orbs:   [ModelEntity] = []
    @State private var arcRoot = Entity()

    // MARK: - Body

    var body: some View {
        // TimelineView drives the update closure at display refresh rate so
        // the pulse animation is smooth instead of stepping once per second.
        TimelineView(.animation) { timeline in
            RealityView { content, attachments in
                ElectrodeEntity.registerComponents()

                let rootEntity = Entity()
                rootEntity.position = [0, 0, 0]
                content.add(rootEntity)

                let arcs = Entity()
                rootEntity.addChild(arcs)
                arcRoot = arcs

                orbs = ElectrodeEntity.buildAll(parent: rootEntity)
                root = rootEntity

                if let panel = attachments.entity(for: "detail") {
                    panel.isEnabled = false
                    rootEntity.addChild(panel)
                }

            } update: { _, attachments in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                updateOrbs(phase: phase)
                updateDetailPanel(attachments)

            } attachments: {
                Attachment(id: "detail") {
                    ElectrodeDetailPanel(channelIndex: appModel.selectedChannel ?? 0)
                        .environment(appModel)
                }
            }
            // ── Spatial tap gesture ───────────────────────────────────────
            .gesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        guard let comp = value.entity.components[ChannelComponent.self] else { return }
                        appModel.selectedChannel = (appModel.selectedChannel == comp.index)
                            ? nil
                            : comp.index
                    }
            )
            // ── Spawn arcs on new spikes ──────────────────────────────────
            .onChange(of: appModel.liveSpikes) { oldSpikes, newSpikes in
                let newlyFired = newSpikes.subtracting(oldSpikes)
                if !newlyFired.isEmpty, newSpikes.count >= 2 {
                    spawnArcs(for: newSpikes)
                }
            }
            // ── Control ornament ──────────────────────────────────────────
            .ornament(attachmentAnchor: .scene(.bottom)) {
                controlBar
            }
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 20) {
            Button {
                openWindow(id: "main")
                dismissWindow(id: appModel.immersiveSpaceID)
            } label: {
                Label("Dashboard", systemImage: "rectangle.on.rectangle")
            }
            .buttonStyle(.borderedProminent)

            Divider().frame(height: 24)

            Button(action: { appModel.startSimulation() }) {
                Label(
                    appModel.isMonitoring ? "Stop" : "Start EEG",
                    systemImage: appModel.isMonitoring ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(.bordered)
            .tint(appModel.isMonitoring ? .red : .green)

            if !appModel.liveSpikes.isEmpty {
                Label("\(appModel.liveSpikes.count) spiking", systemImage: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.15), in: Capsule())
            }

            if appModel.isMonitoring {
                Divider().frame(height: 24)

                let p = appModel.seizureProbability
                let color: Color = p >= 0.7 ? .red : p >= 0.5 ? .orange : .green

                VStack(spacing: 1) {
                    Text(String(format: "%.0f%%", p * 100))
                        .font(.subheadline.bold())
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                    Text("pIctal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .glassBackgroundEffect()
    }

    // MARK: - Orb update (phase-driven for smooth pulse)

    private func updateOrbs(phase: Double) {
        let activity = appModel.channelActivity
        let spikes   = appModel.liveSpikes
        let isAlert  = appModel.seizureProbability > 0.7
        let selected = appModel.selectedChannel
        // 3 Hz sine pulse when alert (0 → 1 → 0)
        let pulse    = isAlert ? Float(0.5 + 0.5 * sin(phase * .pi * 6.0)) : 0

        for (i, orb) in orbs.enumerated() {
            guard i < activity.count else { continue }
            let level   = activity[i]
            let spiking = spikes.contains(i)
            let sel     = selected == i

            let baseScale: Float = sel   ? 2.2
                : spiking              ? 1.4 + level * 0.8
                : 0.8 + level * 0.4
            let alertBoost: Float = (isAlert && spiking) ? pulse * 0.5 : 0
            orb.scale = SIMD3(repeating: baseScale + alertBoost)

            let tint: UIColor
            if sel {
                tint = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 0.95)
            } else if isAlert && spiking {
                let alpha = min(0.75 + CGFloat(level) * 0.15 + CGFloat(pulse) * 0.25, 1.0)
                tint = UIColor(red: 1.0, green: 0.15, blue: 0.15, alpha: alpha)
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
        let electrodePos = ElectrodeEntity.layout[idx].pos
        panel.position = electrodePos + SIMD3<Float>(0.10, 0.02, 0.02)
    }

    // MARK: - Spike arc spawning

    private func spawnArcs(for spikes: Set<Int>) {
        let layout  = ElectrodeEntity.layout
        let isAlert = appModel.seizureProbability > 0.7
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
