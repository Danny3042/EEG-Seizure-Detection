//
//  EventLogView.swift
//  EEGSeizureDetection
//

import SwiftUI

// MARK: - Event log list

struct EventLogView: View {
    @EnvironmentObject var sessionManager: PhoneSessionManager

    var body: some View {
        List {
            if sessionManager.detectionEvents.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "list.bullet",
                    description: Text("Detection events from your Apple Watch will appear here")
                )
            } else {
                ForEach(sessionManager.detectionEvents) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventRow(event: event)
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !sessionManager.detectionEvents.isEmpty {
                Button("Clear") { sessionManager.clearEvents() }
            }
        }
    }
}

// MARK: - Detail view

struct EventDetailView: View {
    let event: DetectionEvent

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Type badge ────────────────────────────────────────────
                VStack(spacing: 8) {
                    Image(systemName: symbolName)
                        .font(.system(size: 56))
                        .foregroundStyle(symbolColor)

                    Text(event.type.rawValue.uppercased())
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(symbolColor)
                }
                .padding(.top, 8)

                // ── pIctal score ──────────────────────────────────────────
                VStack(spacing: 4) {
                    Text(String(format: "%.1f%%", event.probability * 100))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(symbolColor)
                    Text("pIctal Score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // ── Metadata grid ─────────────────────────────────────────
                VStack(spacing: 12) {
                    DetailRow(icon: "clock.fill",
                              label: "Timestamp",
                              value: event.timestamp.formatted(
                                date: .long, time: .standard))

                    DetailRow(icon: "heart.fill",
                              label: "Heart Rate at Detection",
                              value: String(format: "%.0f BPM", event.heartRate))

                    if let battery = event.batteryLevel {
                        DetailRow(icon: batteryIcon(battery),
                                  label: "Watch Battery",
                                  value: "\(Int(battery * 100))%")
                    }

                    DetailRow(icon: "applewatch",
                              label: "Source",
                              value: "Apple Watch Demo")
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Event Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var symbolName: String {
        switch event.type {
        case .elevated:  return "exclamationmark.circle.fill"
        case .alert:     return "exclamationmark.triangle.fill"
        case .emergency: return "exclamationmark.octagon.fill"
        }
    }

    private var symbolColor: Color {
        switch event.type {
        case .elevated:  return .yellow
        case .alert:     return .orange
        case .emergency: return .red
        }
    }

    private func batteryIcon(_ level: Float) -> String {
        switch level {
        case 0..<0.25: return "battery.0percent"
        case 0.25..<0.5: return "battery.25percent"
        case 0.5..<0.75: return "battery.50percent"
        default: return "battery.100percent"
        }
    }
}

// MARK: - Sub-views

struct EventRow: View {
    let event: DetectionEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(symbolColor)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.rawValue)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(event.formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f BPM", event.heartRate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(event.probabilityPercent)
                .font(.title3.bold())
                .foregroundStyle(symbolColor)
        }
        .padding(.vertical, 4)
    }

    private var symbolName: String {
        switch event.type {
        case .elevated:  return "exclamationmark.circle.fill"
        case .alert:     return "exclamationmark.triangle.fill"
        case .emergency: return "exclamationmark.octagon.fill"
        }
    }

    private var symbolColor: Color {
        switch event.type {
        case .elevated:  return .yellow
        case .alert:     return .orange
        case .emergency: return .red
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .multilineTextAlignment(.trailing)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EventLogView()
            .environmentObject(PhoneSessionManager())
    }
}
