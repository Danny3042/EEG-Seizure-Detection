//
//  HomeView.swift
//  EEGSeizureDetection
//
//  "Today" dashboard — status, live vitals, detection readiness, streak.

import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sessionManager:   PhoneSessionManager
    @ObservedObject   private var contact    = EmergencyContactManager.shared
    @Environment(\.openURL) private var openURL

    @AppStorage("detectionSensitivity") private var sensitivity = "Balanced"
    @State private var showDemoOptions = false
    @State private var heartRateHistory: [Double] = HomeView.seedHistory()

    private var displayHeartRate: Int? {
        sessionManager.liveHeartRate ?? healthKitManager.heartRate
    }
    private var hasRiskToday: Bool {
        todaysEvents.contains { $0.type != .elevated }
    }
    private var todaysEvents: [DetectionEvent] {
        sessionManager.detectionEvents.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    private var streakDays: Int {
        guard let lastEvent = sessionManager.detectionEvents.first else { return 12 }
        return max(0, Calendar.current.dateComponents([.day], from: lastEvent.timestamp, to: Date()).day ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    // Watch's authoritative pIctal score — visible when Watch is streaming
                    if sessionManager.liveProbability > 0 || sessionManager.isWatchReachable {
                        LiveWatchCard(
                            probability: sessionManager.liveProbability,
                            heartRate:   sessionManager.liveHeartRate,
                            hrv:         sessionManager.liveHRV,
                            isLive:      sessionManager.isWatchReachable
                        )
                    }

                    StatusCard(hasRisk: hasRiskToday, lastChecked: sessionManager.lastCheckedAt)

                    HStack(spacing: 12) {
                        HeartRateCard(heartRate: displayHeartRate, history: heartRateHistory)
                        MotionCard(activityCode: healthKitManager.activity)
                    }

                    DetectionCard(sensitivity: sensitivity)

                    StreakBanner(eventsToday: todaysEvents.count, streakDays: streakDays)

                    DemoDisclosure(isExpanded: $showDemoOptions, onRun: runDemo)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
                if displayHeartRate != nil {
                    heartRateHistory.append(Double(displayHeartRate!))
                    if heartRateHistory.count > 20 { heartRateHistory.removeFirst() }
                }
            }
        }
        .alert("Emergency Detected",
               isPresented: $sessionManager.showEmergencyAlert) {
            if contact.isConfigured,
               let event = sessionManager.pendingEmergencyEvent,
               let url   = contact.smsURL(probability: event.probability) {
                Button("Message \(contact.contactName)") { openURL(url) }
            }
            Button("Dismiss", role: .cancel) { sessionManager.pendingEmergencyEvent = nil }
        } message: {
            if let event = sessionManager.pendingEmergencyEvent {
                let pct = Int(event.probability * 100)
                Text(contact.isConfigured
                     ? "pIctal score reached \(pct)%. Send an alert to \(contact.contactName)?"
                     : "pIctal score reached \(pct)%. Add an emergency contact in Settings to enable caregiver alerts.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.largeTitle.bold())
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            WatchBadge(isConnected: sessionManager.isWatchPaired && sessionManager.isWatchAppInstalled,
                       isLive: sessionManager.isWatchReachable,
                       battery: sessionManager.watchBatteryLevel)
        }
        .padding(.top, 4)
    }

    // MARK: - Demo

    private func runDemo(_ scenario: DemoTier) {
        let battery = sessionManager.watchBatteryLevel
        let event = DetectionEvent(probability: scenario.probability,
                                    heartRate: Double(displayHeartRate ?? 75),
                                    type: scenario.eventType,
                                    batteryLevel: battery)
        sessionManager.detectionEvents.insert(event, at: 0)
        if event.type == .emergency {
            sessionManager.pendingEmergencyEvent = event
            sessionManager.showEmergencyAlert    = true
        }
        showDemoOptions = false
    }

    private static func seedHistory() -> [Double] {
        (0..<20).map { _ in Double.random(in: 68...78) }
    }
}

// MARK: - Watch connectivity badge

private struct WatchBadge: View {
    let isConnected: Bool   // paired + app installed — stable, not flickery
    let isLive: Bool        // currently reachable for live messaging
    let battery: Float?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            if let battery, isConnected {
                Text("Watch \(Int(battery * 100))%")
                    .font(.subheadline.bold())
            } else {
                Text(isConnected ? "Watch Connected" : "Watch Offline")
                    .font(.subheadline.bold())
            }
            if isConnected && !isLive {
                Image(systemName: "moon.zzz.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}

// MARK: - Status card

private struct StatusCard: View {
    let hasRisk: Bool
    let lastChecked: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.25))
                    Image(systemName: hasRisk ? "exclamationmark.triangle.fill" : "checkmark")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasRisk ? "Risk Detected" : "All clear")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Monitoring active · checked \(timeAgo(context.date))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
        }
        .padding()
        .background(hasRisk ? Color.red : Color.blue, in: RoundedRectangle(cornerRadius: 18))
    }

    private func timeAgo(_ now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(lastChecked)))
        switch s {
        case 0..<60:   return "\(s)s ago"
        case 60..<3600:
            let m = s / 60
            let rem = s % 60
            return rem == 0 ? "\(m)m ago" : "\(m)m \(rem)s ago"
        default:
            let h = s / 3600
            let m = (s % 3600) / 60
            return m == 0 ? "\(h)h ago" : "\(h)h \(m)m ago"
        }
    }
}

// MARK: - Heart rate card

private struct HeartRateCard: View {
    let heartRate: Int?
    let history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Heart rate", systemImage: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(heartRate ?? 0)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("bpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Sparkline(values: history)
                .stroke(Color.red, lineWidth: 1.5)
                .frame(height: 28)

            Text("Resting")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1,
              let min = values.min(), let max = values.max(), max > min else { return path }

        let stepX = rect.width / CGFloat(values.count - 1)
        func y(_ v: Double) -> CGFloat {
            rect.height - CGFloat((v - min) / (max - min)) * rect.height
        }
        path.move(to: CGPoint(x: 0, y: y(values[0])))
        for (i, v) in values.enumerated().dropFirst() {
            path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: y(v)))
        }
        return path
    }
}

// MARK: - Motion card

private struct MotionCard: View {
    let activityCode: String

    private var label: String {
        switch activityCode {
        case "1": return "Walking"
        case "3": return "Running"
        default:  return "Normal"
        }
    }

    private var bars: [CGFloat] {
        switch activityCode {
        case "1": return [10, 22, 14, 26, 12]
        case "3": return [26, 14, 28, 16, 24]
        default:  return [10, 16, 9, 15, 8]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Motion")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(label)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 8, height: h)
                }
            }
            .frame(height: 28, alignment: .bottom)

            Text("Steady · no tremor")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Detection card

private struct DetectionCard: View {
    let sensitivity: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Detection")
                    .font(.headline)
                Spacer()
                Text("Ready")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
            }

            HStack(spacing: 0) {
                DetectionStat(label: "Sensitivity", value: sensitivity)
                DetectionStat(label: "Baseline", value: "Calibrated 2d ago")
                DetectionStat(label: "Model", value: "HR + motion")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct DetectionStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Streak banner

private struct StreakBanner: View {
    let eventsToday: Int
    let streakDays: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(eventsToday == 0 ? "No events today" : "\(eventsToday) event\(eventsToday == 1 ? "" : "s") logged today")
                    .font(.subheadline.bold())
                if eventsToday == 0 {
                    Text("\(streakDays) days seizure-free — your longest streak yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Check the History tab for details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.2)))
    }
}

// MARK: - Demo disclosure

private enum DemoTier: String, CaseIterable, Identifiable {
    case elevated = "Elevated"
    case alert    = "High Risk"
    case emergency = "Emergency"

    var id: String { rawValue }

    var probability: Double {
        switch self {
        case .elevated:  return 0.55
        case .alert:     return 0.78
        case .emergency: return 0.93
        }
    }

    var eventType: DetectionEvent.EventType {
        switch self {
        case .elevated:  return .elevated
        case .alert:     return .alert
        case .emergency: return .emergency
        }
    }

    var color: Color {
        switch self {
        case .elevated:  return .yellow
        case .alert:     return .orange
        case .emergency: return .red
        }
    }
}

private struct DemoDisclosure: View {
    @Binding var isExpanded: Bool
    let onRun: (DemoTier) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "play.fill")
                        .font(.caption)
                    Text("Simulate a detection (demo)")
                        .font(.subheadline.bold())
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(.secondary)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(DemoTier.allCases) { tier in
                    Button { onRun(tier) } label: {
                        HStack {
                            Circle().fill(tier.color).frame(width: 8, height: 8)
                            Text(tier.rawValue)
                            Spacer()
                            Text(String(format: "%.0f%%", tier.probability * 100))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Live Watch pIctal card

// Shown on the iPhone dashboard whenever the Watch is paired and sending data.
// The Watch is the authoritative sensor for seizure detection — this card
// makes its real-time pIctal score the most prominent element on screen.
private struct LiveWatchCard: View {
    let probability: Double
    let heartRate:   Int?
    let hrv:         Double?
    let isLive:      Bool

    private var color: Color {
        probability >= 0.7 ? .red : probability >= 0.5 ? .orange : .green
    }
    private var riskLabel: String {
        probability >= 0.7 ? "High Risk" : probability >= 0.5 ? "Elevated" : "Normal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Watch · pIctal Score", systemImage: "applewatch.radiowaves.left.and.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(isLive ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(isLive ? "Live" : "Last known")
                        .font(.caption2.bold())
                        .foregroundStyle(isLive ? .green : .secondary)
                }
            }

            // Gauge row
            HStack(spacing: 18) {
                // Ring
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
                .frame(width: 88, height: 88)

                // Vitals
                VStack(alignment: .leading, spacing: 8) {
                    if let hr = heartRate {
                        WatchVital(icon: "heart.fill", color: .red,
                                   value: "\(hr)", unit: "bpm")
                    }
                    if let hv = hrv {
                        WatchVital(icon: "waveform.path.ecg", color: .purple,
                                   value: String(format: "%.0f", hv), unit: "ms HRV")
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

private struct WatchVital: View {
    let icon: String; let color: Color; let value: String; let unit: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value).font(.subheadline.bold()).contentTransition(.numericText())
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(PhoneSessionManager())
}
