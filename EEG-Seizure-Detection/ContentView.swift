//
//  ContentView.swift
//  EEGSeizureDetection
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sessionManager:   PhoneSessionManager
    @ObservedObject   private var contact    = EmergencyContactManager.shared

    @State private var isMonitoring        = false
    @State private var showContactSettings = false
    @Environment(\.openURL) private var openURL

    // Watch live stream takes priority over HealthKit value
    private var displayProbability: Double {
        sessionManager.liveProbability > 0
            ? sessionManager.liveProbability
            : (healthKitManager.epilepsyPredictionValue ?? 0)
    }
    private var isLiveStreaming: Bool { sessionManager.liveProbability > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── 1. Connectivity status ────────────────────────────
                    ConnectivityBadge(isReachable: sessionManager.isWatchReachable)

                    // ── 2. Live pIctal gauge ──────────────────────────────
                    LiveProbabilityGauge(
                        probability: displayProbability,
                        isLive: isLiveStreaming
                    )
                    .padding(.horizontal)

                    // Live Watch vitals (visible only while streaming)
                    if isLiveStreaming {
                        HStack(spacing: 16) {
                            if let hr = sessionManager.liveHeartRate {
                                LiveMetricChip(icon: "heart.fill",
                                               value: "\(hr)", unit: "BPM", color: .red)
                            }
                            if let hrv = sessionManager.liveHRV {
                                LiveMetricChip(icon: "waveform.path.ecg",
                                               value: String(format: "%.0f", hrv),
                                               unit: "ms", color: .blue)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut, value: isLiveStreaming)
                    }

                    // ── HealthKit metrics ─────────────────────────────────
                    VStack(spacing: 12) {
                        if let hr = healthKitManager.heartRate {
                            MetricCard(title: "Heart Rate",
                                       value: "\(hr)", unit: "BPM",
                                       icon: "heart.fill")
                        }
                        if let hrv = healthKitManager.hrv {
                            MetricCard(title: "HRV",
                                       value: String(format: "%.1f", hrv),
                                       unit: "ms", icon: "waveform.path.ecg")
                        }
                        MetricCard(title: "Activity",
                                   value: activityDescription, unit: "",
                                   icon: "figure.walk")
                    }
                    .padding(.horizontal)

                    // ── Controls ──────────────────────────────────────────
                    VStack(spacing: 12) {
                        Button(action: toggleMonitoring) {
                            Label(isMonitoring ? "Stop Monitoring" : "Start Monitoring",
                                  systemImage: isMonitoring ? "stop.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isMonitoring ? Color.red : Color.green)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }

                        NavigationLink(destination: EventLogView()) {
                            Label("Event Log (\(sessionManager.detectionEvents.count))",
                                  systemImage: "list.bullet")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Seizure Detection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showContactSettings = true } label: {
                        Image(systemName: contact.isConfigured
                              ? "person.crop.circle.fill.badge.checkmark"
                              : "person.crop.circle.badge.plus")
                        .foregroundStyle(contact.isConfigured ? .green : .secondary)
                    }
                }
            }
        }
        // ── Emergency contact sheet ───────────────────────────────────────
        .sheet(isPresented: $showContactSettings) {
            EmergencyContactSettingsView()
        }
        // ── Emergency alert ───────────────────────────────────────────────
        .alert("🚨 Emergency Detected",
               isPresented: $sessionManager.showEmergencyAlert) {
            if contact.isConfigured,
               let event = sessionManager.pendingEmergencyEvent,
               let url   = contact.smsURL(probability: event.probability) {
                Button("Message \(contact.contactName)") { openURL(url) }
            }
            Button("Dismiss", role: .cancel) {
                sessionManager.pendingEmergencyEvent = nil
            }
        } message: {
            if let event = sessionManager.pendingEmergencyEvent {
                let pct = Int(event.probability * 100)
                if contact.isConfigured {
                    Text("pIctal score reached \(pct)%. Send an alert to \(contact.contactName)?")
                } else {
                    Text("pIctal score reached \(pct)%. Add an emergency contact in settings to enable caregiver alerts.")
                }
            }
        }
    }

    private var activityDescription: String {
        switch healthKitManager.activity {
        case "0": return "Stationary"
        case "1": return "Walking"
        case "3": return "Running"
        default:  return "Unknown"
        }
    }

    private func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring { healthKitManager.startMonitoringActivity() }
    }
}

// MARK: - Connectivity badge

struct ConnectivityBadge: View {
    let isReachable: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isReachable ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isReachable ? "Watch Connected" : "Watch Offline")
                .font(.caption.bold())
                .foregroundStyle(isReachable ? .green : .red)
            if !isReachable {
                Text("· events queued for sync")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background((isReachable ? Color.green : Color.red).opacity(0.1),
                    in: Capsule())
    }
}

// MARK: - Live pIctal gauge (semi-circular arc)

struct LiveProbabilityGauge: View {
    let probability: Double
    let isLive: Bool

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background half-arc
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 22)
                    .rotationEffect(.degrees(180))

                // Colored fill
                Circle()
                    .trim(from: 0, to: CGFloat(probability) * 0.5)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))
                    .animation(.easeInOut(duration: 0.5), value: probability)

                // Centre readout
                VStack(spacing: 2) {
                    if isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 7, height: 7)
                                .opacity(pulse ? 1 : 0.3)
                                .animation(.easeInOut(duration: 0.8).repeatForever(),
                                           value: pulse)
                            Text("LIVE")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    Text(String(format: "%.1f%%", probability * 100))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("pIctal Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(riskLabel)
                        .font(.caption.bold())
                        .foregroundStyle(gaugeColor)
                }
                .offset(y: 28)
            }
            .frame(width: 260, height: 130)
            .clipped()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .onAppear { pulse = true }
    }

    private var gaugeColor: Color {
        if probability < 0.3 { return .green }
        if probability < 0.7 { return .orange }
        return .red
    }

    private var riskLabel: String {
        if probability < 0.3 { return "Normal" }
        if probability < 0.7 { return "Elevated" }
        return "High Risk"
    }
}

// MARK: - Emergency contact settings sheet

struct EmergencyContactSettingsView: View {
    @ObservedObject private var contact = EmergencyContactManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $contact.contactName)
                    TextField("Phone number", text: $contact.contactPhone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Emergency Contact")
                } footer: {
                    Text("When a seizure emergency is detected, you will be prompted to send an SMS alert to this contact.")
                }

                if contact.isConfigured {
                    Section {
                        Label("Configured — \(contact.contactName)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Caregiver Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Supporting views

struct MetricCard: View {
    let title: String
    let value: String
    let unit:  String
    let icon:  String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2).foregroundStyle(.blue).frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(.title2).fontWeight(.semibold)
                    if !unit.isEmpty {
                        Text(unit).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

private struct LiveMetricChip: View {
    let icon: String; let value: String; let unit: String; let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value).font(.subheadline.bold()).contentTransition(.numericText())
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(PhoneSessionManager())
}
