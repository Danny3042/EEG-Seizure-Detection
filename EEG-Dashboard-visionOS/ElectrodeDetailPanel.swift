//
//  ElectrodeDetailPanel.swift
//  EEG-Dashboard-visionOS
//
//  Floating glass panel shown next to a selected electrode in the immersive space.

import SwiftUI

struct ElectrodeDetailPanel: View {
    let channelIndex: Int
    @Environment(AppModel.self) private var appModel

    // MARK: - Derived values

    private var channelName: String {
        guard channelIndex < ElectrodeEntity.layout.count else { return "Ch\(channelIndex + 1)" }
        return ElectrodeEntity.layout[channelIndex].name
    }

    private var activity: Float {
        guard channelIndex < appModel.channelActivity.count else { return 0 }
        return appModel.channelActivity[channelIndex]
    }

    private var spikeRate: Float {
        guard channelIndex < appModel.spikeRates.count else { return 0 }
        return appModel.spikeRates[channelIndex]
    }

    private var waveform: [Float] {
        guard channelIndex < appModel.channelWaveforms.count else { return [] }
        return appModel.channelWaveforms[channelIndex]
    }

    private var isSpiking: Bool { appModel.liveSpikes.contains(channelIndex) }

    private var accentColor: Color { isSpiking ? .orange : .cyan }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header ────────────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundStyle(accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(channelName)
                        .font(.title.bold())
                    Text("Channel \(channelIndex + 1)  ·  10-20 system")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSpiking {
                    Label("Spiking", systemImage: "bolt.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.orange.opacity(0.18))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            Divider()

            // ── Metrics row ───────────────────────────────────────────────
            HStack(spacing: 24) {
                MetricTile(
                    label: "Spike Rate",
                    value: String(format: "%.1f%%", spikeRate * 100),
                    color: spikeRate > 0.08 ? .orange : .green
                )
                MetricTile(
                    label: "Activity",
                    value: String(format: "%.2f µV", Double(activity) * 100),
                    color: activity > 0.6 ? .red : .cyan
                )
                MetricTile(
                    label: "Seizure P",
                    value: String(format: "%.0f%%", appModel.displayProbability * 100),
                    color: appModel.displayProbability > 0.7 ? .red : .green
                )
            }

            // ── Waveform ──────────────────────────────────────────────────
            if !waveform.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Raw Waveform  (last 128 samples)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    WaveformCanvas(samples: waveform, color: accentColor)
                        .frame(height: 72)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            // ── Dismiss hint ──────────────────────────────────────────────
            HStack {
                Spacer()
                Label("Tap electrode to dismiss", systemImage: "hand.tap")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(22)
        .frame(width: 340)
        .glassBackgroundEffect()
    }
}

// MARK: - Sub-views

private struct MetricTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
        }
    }
}

struct WaveformCanvas: View {
    let samples: [Float]
    let color:   Color

    var body: some View {
        Canvas { ctx, size in
            guard samples.count > 1 else { return }
            let step = size.width / CGFloat(samples.count - 1)
            let mid  = size.height / 2
            let amp  = size.height * 0.42
            var path = Path()
            path.move(to: CGPoint(x: 0,
                                  y: mid - CGFloat(samples[0]) * amp))
            for (i, s) in samples.dropFirst().enumerated() {
                path.addLine(to: CGPoint(x: CGFloat(i + 1) * step,
                                         y: mid - CGFloat(s) * amp))
            }
            ctx.stroke(path, with: .color(color), lineWidth: 1.5)
        }
        .padding(8)
    }
}

#Preview {
    ElectrodeDetailPanel(channelIndex: 9)
        .environment(AppModel())
}
