//
//  WatchContentView.swift
//  SeizureDetection-Watch Watch App
//

import SwiftUI
import Combine
import UserNotifications
#if os(watchOS)
import WatchKit
#endif

// MARK: - Simulation scenarios

enum SimulationScenario: String, CaseIterable, Identifiable {
    case low        = "Low Risk"
    case elevated   = "Elevated"
    case high       = "High Risk"
    case escalating = "Escalating"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .low:        return "Stable — probability 5–20%"
        case .elevated:   return "Moderate — probability 40–65%"
        case .high:       return "Dangerous — probability 75–95%"
        case .escalating: return "Builds low → high over ~60 s"
        }
    }

    var color: Color {
        switch self {
        case .low:        return .green
        case .elevated:   return .orange
        case .high:       return .red
        case .escalating: return .purple
        }
    }

    var icon: String {
        switch self {
        case .low:        return "checkmark.shield.fill"
        case .elevated:   return "exclamationmark.triangle.fill"
        case .high:       return "bolt.heart.fill"
        case .escalating: return "chart.line.uptrend.xyaxis"
        }
    }

    func values(at t: Double) -> (probability: Double, heartRate: Int, hrv: Double) {
        switch self {
        case .low:
            return (0.10 + 0.08 * sin(t / 8),
                    65 + Int(5 * sin(t / 10)),
                    55 + 8 * sin(t / 12))
        case .elevated:
            return (0.52 + 0.12 * sin(t / 6),
                    92 + Int(8 * sin(t / 8)),
                    32 + 6 * sin(t / 10))
        case .high:
            let noise = Double.random(in: -0.04...0.04)
            return (max(0, min(0.82 + 0.12 * sin(t / 4) + noise, 1)),
                    118 + Int(10 * sin(t / 5)),
                    max(5, 14 + 5 * sin(t / 7)))
        case .escalating:
            let prog = min(t / 60, 1.0)
            return (max(0, min(0.08 + 0.87 * prog + 0.05 * sin(t / 3), 1)),
                    65 + Int(55 * prog) + Int(5 * sin(t / 5)),
                    max(5, 55 - 40 * prog + 4 * sin(t / 8)))
        }
    }
}

// MARK: - Root view

struct WatchContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sessionManager:   WatchSessionManager
    #if os(watchOS)
    @StateObject private var workoutSessionManager = WorkoutSessionManager()
    #endif

    // ── Real monitoring ───────────────────────────────────────────────────
    @State private var isMonitoring = false

    // ── Demo state (all @State — no class, no threading issues) ──────────
    @State private var isDemoRunning   = false
    @State private var demoScenario    = SimulationScenario.low
    @State private var demoElapsed:    Double = 0
    @State private var demoProbability: Double = 0
    @State private var demoHeartRate:  Int    = 65
    @State private var demoHRV:        Double = 55
    @State private var demoPrevProb:   Double = 0

    /// Fires every second on the main RunLoop — safe, no actor issues.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // ── Derived display values ────────────────────────────────────────────
    private var displayProbability: Double {
        isDemoRunning ? demoProbability : (healthKitManager.epilepsyPredictionValue ?? 0)
    }
    private var displayHeartRate: Int? {
        isDemoRunning ? demoHeartRate : healthKitManager.heartRate
    }
    private var displayHRV: Double? {
        isDemoRunning ? demoHRV : healthKitManager.hrv
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {

                    // ── Demo banner ───────────────────────────────────────
                    if isDemoRunning {
                        DemoBanner(scenario: demoScenario, onStop: stopDemo)
                    }

                    // ── Probability ring ──────────────────────────────────
                    ProbabilityRingView(probability: displayProbability)
                        .frame(width: 120, height: 120)
                        .padding(.top, isDemoRunning ? 2 : 8)

                    // ── Status text ───────────────────────────────────────
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                        .multilineTextAlignment(.center)

                    // ── Vitals row ────────────────────────────────────────
                    HStack(spacing: 12) {
                        if let hr = displayHeartRate {
                            WatchVitalChip(icon: "heart.fill",
                                           value: "\(hr)", unit: "bpm",
                                           color: .red)
                        }
                        if let hv = displayHRV {
                            WatchVitalChip(icon: "waveform.path.ecg",
                                           value: String(format: "%.0f", hv), unit: "ms",
                                           color: .blue)
                        }
                    }

                    Divider().padding(.vertical, 2)

                    // ── Monitor button ────────────────────────────────────
                    Button(action: toggleMonitoring) {
                        Label(isMonitoring ? "Stop" : "Monitor",
                              systemImage: isMonitoring ? "stop.fill" : "heart.text.square.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isMonitoring ? .gray : .green)
                    .disabled(isDemoRunning)

                    // ── Demo button ───────────────────────────────────────
                    NavigationLink {
                        DemoPickerView(onSelect: startDemo)
                    } label: {
                        Label("Demo", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .disabled(isMonitoring)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
            .navigationTitle("EEG Watch")
            .navigationBarTitleDisplayMode(.inline)
        }
        // ── Demo tick ─────────────────────────────────────────────────────
        .onReceive(ticker) { _ in
            guard isDemoRunning else { return }
            demoTick()
        }
        .onAppear {
            #if os(watchOS)
            workoutSessionManager.requestAuthorization()
            #endif
        }
    }

    // MARK: - Demo logic

    private func startDemo(scenario: SimulationScenario) {
        demoScenario    = scenario
        demoElapsed     = 0
        demoPrevProb    = 0
        demoProbability = 0
        demoHeartRate   = 65
        demoHRV         = 55
        isDemoRunning   = true
        #if os(watchOS)
        workoutSessionManager.start()
        #endif
    }

    private func stopDemo() {
        isDemoRunning   = false
        demoElapsed     = 0
        demoProbability = 0
        demoHeartRate   = 65
        demoHRV         = 55
        demoPrevProb    = 0
        #if os(watchOS)
        workoutSessionManager.stop()
        #endif
    }

    private func demoTick() {
        demoElapsed += 1
        let (p, hr, hv) = demoScenario.values(at: demoElapsed)
        demoProbability = p
        demoHeartRate   = hr
        demoHRV         = hv
        sessionManager.sendLiveData(probability: p, heartRate: hr, hrv: hv, battery: currentBatteryLevel())
        checkThresholds(newProb: p)
        demoPrevProb = p
    }

    private func currentBatteryLevel() -> Float? {
        #if os(watchOS)
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        let level = WKInterfaceDevice.current().batteryLevel
        return level >= 0 ? level : nil
        #else
        return nil
        #endif
    }

    private func checkThresholds(newProb p: Double) {
        let battery = currentBatteryLevel()
        if demoPrevProb < 0.5, p >= 0.5 {
            sessionManager.sendDetectionEvent(
                DetectionEvent(probability: p, heartRate: Double(demoHeartRate),
                               type: .elevated, batteryLevel: battery))
        }
        if demoPrevProb < 0.7, p >= 0.7 {
            scheduleNotification(title: "Seizure Risk Alert",
                                 body: "You're showing signs of stress. Stay safe.")
            sessionManager.sendDetectionEvent(
                DetectionEvent(probability: p, heartRate: Double(demoHeartRate),
                               type: .alert, batteryLevel: battery))
        }
        if demoPrevProb < 0.9, p >= 0.9 {
            scheduleNotification(title: "Emergency — High Seizure Risk",
                                 body: "Probability exceeded 90%. Seek assistance immediately.")
            sessionManager.sendDetectionEvent(
                DetectionEvent(probability: p, heartRate: Double(demoHeartRate),
                               type: .emergency, batteryLevel: battery))
        }
    }

    // MARK: - Real monitoring

    private var statusText: String {
        if isDemoRunning {
            if demoProbability >= 0.9 { return "🚨 Emergency" }
            if demoProbability >= 0.7 { return "⚠️ High Risk" }
            if demoProbability >= 0.5 { return "Elevated" }
            return "Simulating…"
        }
        if !isMonitoring { return "Idle" }
        if let risk = healthKitManager.seizureRisk, risk { return "Risk Detected" }
        return "Normal"
    }

    private var statusColor: Color {
        let p = displayProbability
        if p >= 0.7 { return .red }
        if p >= 0.5 { return .orange }
        return (isMonitoring || isDemoRunning) ? .green : .secondary
    }

    private func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            healthKitManager.startMonitoringActivity()
            #if os(watchOS)
            workoutSessionManager.start()
            #endif
        } else {
            #if os(watchOS)
            workoutSessionManager.stop()
            #endif
        }
        sessionManager.sendMonitoringStatus(isMonitoring: isMonitoring)
    }
}

// MARK: - Demo picker

struct DemoPickerView: View {
    let onSelect: (SimulationScenario) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(SimulationScenario.allCases) { scenario in
                    Button {
                        onSelect(scenario)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: scenario.icon)
                                .font(.title3)
                                .foregroundStyle(scenario.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scenario.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(scenario.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(scenario.color.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .navigationTitle("Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sub-views

struct ProbabilityRingView: View {
    let probability: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 9)
            Circle()
                .trim(from: 0, to: probability)
                .stroke(ringColor,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: probability)
            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", probability * 100))
                    .font(.title2.bold())
                    .contentTransition(.numericText())
                Text("Risk")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ringColor: Color {
        if probability < 0.3 { return .green }
        if probability < 0.7 { return .orange }
        return .red
    }
}

private struct WatchVitalChip: View {
    let icon: String; let value: String; let unit: String; let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.caption2).foregroundStyle(color)
            Text(value).font(.caption.bold()).contentTransition(.numericText())
            Text(unit).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct DemoBanner: View {
    let scenario: SimulationScenario
    let onStop:   () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: scenario.icon)
                .font(.caption2).foregroundStyle(scenario.color)
            Text(scenario.rawValue)
                .font(.caption2.bold()).foregroundStyle(scenario.color)
            Spacer()
            Button(action: onStop) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(scenario.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Notification helper

private func scheduleNotification(title: String, body: String) {
    let content       = UNMutableNotificationContent()
    content.title     = title
    content.body      = body
    content.sound     = .default
    let trigger       = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request       = UNNotificationRequest(identifier: UUID().uuidString,
                                              content: content,
                                              trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
        if let error { print("Notification error: \(error)") }
    }
}

// MARK: - Preview

#Preview {
    WatchContentView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(WatchSessionManager())
}
