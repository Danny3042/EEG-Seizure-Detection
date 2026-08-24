//
//  DashboardView.swift
//  EEG-Dashboard-visionOS
//
//  Main 2-D control panel. Shows pIctal gauge, live vitals, channel heat-map,
//  window-launchers for all spatial sub-views, and the recent event feed.

import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow)  private var openWindow

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerRow
                    if appModel.watchLiveProbability != nil || appModel.isWatchCloudConnected {
                        WatchCloudCard(
                            probability: appModel.watchLiveProbability ?? 0,
                            heartRate:   appModel.watchLiveHeartRate,
                            hrv:         appModel.watchLiveHRV,
                            isConnected: appModel.isWatchCloudConnected
                        )
                    }
                    gaugeAndVitalsRow
                    windowLaunchGrid
                    channelHeatMap
                    recentEventsFeed
                }
                .padding(28)
            }
            .background(.clear)
            .navigationTitle("EEG Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appModel.startSimulation() } label: {
                        Label(
                            appModel.isMonitoring ? "Stop" : "Start EEG",
                            systemImage: appModel.isMonitoring ? "stop.fill" : "play.fill"
                        )
                    }
                    .tint(appModel.isMonitoring ? .red : .green)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 860, minHeight: 680)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EEG Seizure Detection")
                    .font(.largeTitle.bold())
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle()
                    .fill(appModel.isMonitoring ? Color.green : Color.secondary)
                    .frame(width: 10, height: 10)
                    .scaleEffect(appModel.isMonitoring ? 1 : 0.8)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                               value: appModel.isMonitoring)
                Text(appModel.isMonitoring ? "Monitoring Active" : "Idle")
                    .font(.subheadline.bold())
                    .foregroundStyle(appModel.isMonitoring ? .green : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
        }
    }

    // MARK: - Gauge + vitals

    private var gaugeAndVitalsRow: some View {
        HStack(alignment: .top, spacing: 20) {
            ProbabilityGaugeCard(probability: appModel.displayProbability)
                .frame(width: 270)

            VStack(spacing: 14) {
                // Heart rate: mirrors WatchCloudCard — Watch value wins when connected,
                // falls back to this device's own HealthKit read, then the EEG-derived sim.
                VitalCard(icon: "heart.fill", color: .red,
                          label: "Heart Rate",
                          value: appModel.displayHeartRate.map { "\(Int($0))" } ?? "--",
                          unit: "bpm",
                          badge: badgeText(for: appModel.heartRateSource))
                // HRV: mirrors WatchCloudCard — Watch value wins, else HealthKit.
                VitalCard(icon: "waveform.path.ecg", color: .purple,
                          label: "HRV (SDNN)",
                          value: appModel.displayHRV.map { String(format: "%.0f", $0) } ?? "--",
                          unit: "ms",
                          badge: badgeText(for: appModel.hrvSource))
                // Per-channel spike count has no Watch equivalent — always local to
                // this device's own 22-channel EEG simulation.
                VitalCard(icon: "bolt.fill", color: .orange,
                          label: "Spiking",
                          value: "\(appModel.liveSpikes.count)",
                          unit: "/ 22 ch",
                          badge: "Local")
                // State: mirrors WatchCloudCard's risk thresholds via displayProbability
                // instead of the local-only detectionState, so it never disagrees with
                // the pIctal score shown everywhere else.
                VitalCard(icon: "brain.head.profile", color: detectionColor,
                          label: "State",
                          value: detectionLabel,
                          unit: "",
                          badge: appModel.watchLiveProbability != nil ? "Watch" : nil)

                // HealthKit auth status hint
                if let err = appModel.hkManager.authorizationError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !appModel.hkManager.isAuthorized {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.text.square")
                            .foregroundStyle(.secondary)
                        Text("Authorize HealthKit in Settings to show real heart rate and HRV.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var detectionColor: Color {
        let p = appModel.displayProbability
        return p >= 0.7 ? .red : p >= 0.5 ? .orange : .green
    }

    private var detectionLabel: String {
        let p = appModel.displayProbability
        return p >= 0.7 ? "High Risk" : p >= 0.5 ? "Elevated" : "Normal"
    }

    private func badgeText(for source: AppModel.VitalSource) -> String? {
        switch source {
        case .watch:       return "Watch"
        case .healthKit:   return "Live"
        case .simulated:   return "Sim"
        case .unavailable: return "—"
        }
    }

    // MARK: - Window launchers

    private var windowLaunchGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spatial Views")
                .font(.headline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                WindowLaunchButton(icon: "cube.fill",
                                   label: "Brain View",
                                   description: "3-D electrode map") {
                    openWindow(id: appModel.immersiveSpaceID)
                }
                WindowLaunchButton(icon: "chart.xyaxis.line",
                                   label: "Timeline",
                                   description: "pIctal history") {
                    openWindow(id: "timeline")
                }
                WindowLaunchButton(icon: "list.bullet.clipboard.fill",
                                   label: "Event Log",
                                   description: "Detection history") {
                    openWindow(id: "eventlog")
                }
                WindowLaunchButton(icon: "waveform",
                                   label: "Spike Train",
                                   description: "22-ch raster") {
                    openWindow(id: "spiketrain")
                }
            }
        }
    }

    // MARK: - Channel heat-map

    private var channelHeatMap: some View {
        let names = ElectrodeEntity.layout.map(\.name)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Channel Activity")
                .font(.headline)
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                spacing: 8
            ) {
                ForEach(Array(appModel.channelActivity.enumerated()), id: \.offset) { i, level in
                    ChannelMiniCard(
                        name: i < names.count ? names[i] : "Ch\(i+1)",
                        level: level,
                        isSpiking: appModel.liveSpikes.contains(i)
                    )
                }
            }
        }
    }

    // MARK: - Recent events

    @ViewBuilder
    private var recentEventsFeed: some View {
        if !appModel.eventLog.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Events")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("See All") { openWindow(id: "eventlog") }
                        .font(.subheadline)
                }
                VStack(spacing: 8) {
                    ForEach(appModel.eventLog.prefix(4)) { event in
                        DashboardEventRow(event: event)
                    }
                }
            }
        }
    }
}

// MARK: - Watch cloud card

// The Watch is the authoritative sensor; its pIctal score reaches this app
// via CloudKit (relayed through the iPhone — WatchConnectivity can't reach
// visionOS directly). This card makes that real-time score prominent,
// distinct from the EEG-simulation gauge below it.
private struct WatchCloudCard: View {
    let probability: Double
    let heartRate:   Int?
    let hrv:         Double?
    let isConnected: Bool

    private var color: Color {
        probability >= 0.7 ? .red : probability >= 0.5 ? .orange : .green
    }
    private var riskLabel: String {
        probability >= 0.7 ? "High Risk" : probability >= 0.5 ? "Elevated" : "Normal"
    }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: probability)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: probability)
                VStack(spacing: 1) {
                    Text(String(format: "%.0f%%", probability * 100))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                    Text(riskLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                    Text("Watch · pIctal Score")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Circle()
                        .fill(isConnected ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(isConnected ? "Synced" : "Offline")
                        .font(.caption2.bold())
                        .foregroundStyle(isConnected ? .green : .secondary)
                }
                HStack(spacing: 18) {
                    if let hr = heartRate {
                        Label("\(hr) bpm", systemImage: "heart.fill")
                            .font(.callout).foregroundStyle(.red)
                    }
                    if let hv = hrv {
                        Label(String(format: "%.0f ms", hv), systemImage: "waveform.path.ecg")
                            .font(.callout).foregroundStyle(.purple)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Gauge card

private struct ProbabilityGaugeCard: View {
    let probability: Double

    private var color: Color {
        probability >= 0.7 ? .red : probability >= 0.5 ? .orange : .green
    }
    private var label: String {
        probability >= 0.7 ? "High Risk" : probability >= 0.5 ? "Elevated" : "Normal"
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("pIctal Score")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: probability)
                    .stroke(color, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: probability)
                // Alert ring
                if probability >= 0.7 {
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 6)
                        .scaleEffect(1.14)
                }
                VStack(spacing: 4) {
                    Text(String(format: "%.0f%%", probability * 100))
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
            }
            .frame(width: 200, height: 200)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vital card

private struct VitalCard: View {
    let icon: String; let color: Color
    let label: String; let value: String; let unit: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2.bold())
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let badge {
                let isLive = badge == "Watch" || badge == "Live"
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isLive ? .green : .secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(isLive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12),
                                in: Capsule())
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Window launch button

private struct WindowLaunchButton: View {
    let icon: String; let label: String; let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label).font(.subheadline.bold())
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Channel mini-card

private struct ChannelMiniCard: View {
    let name: String; let level: Float; let isSpiking: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isSpiking ? Color.orange : Color.cyan)
            .opacity(0.12 + Double(level) * 0.75)
            .frame(height: 32)
            .overlay(
                Text(name)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSpiking ? .orange : .cyan)
            )
    }
}

// MARK: - Event row

private struct DashboardEventRow: View {
    let event: DetectionEvent

    private var color: Color {
        switch event.type {
        case .elevated:  return .yellow
        case .alert:     return .orange
        case .emergency: return .red
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: event.type == .emergency
                  ? "cross.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.rawValue).font(.subheadline.bold())
                Text(event.formattedTime).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.probabilityPercent)
                .font(.headline).foregroundStyle(color)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview(windowStyle: .automatic) {
    DashboardView()
        .environment(AppModel())
}
