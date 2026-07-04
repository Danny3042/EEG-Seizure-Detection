//
//  EventLogWindowView.swift
//  EEG-Dashboard-visionOS
//
//  Floating window listing every detected event with probability, heart rate,
//  and timestamp — spatially styled with glass material rows.

import SwiftUI

struct EventLogWindowView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            Group {
                if appModel.eventLog.isEmpty {
                    ContentUnavailableView(
                        "No Events Detected",
                        systemImage: "list.bullet.clipboard",
                        description: Text(
                            "Start the EEG simulation in the Dashboard — detection events appear here."
                        )
                    )
                } else {
                    List {
                        ForEach(appModel.eventLog) { event in
                            EventWindowRow(event: event)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16,
                                                          bottom: 4, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Event Log")
            .toolbar {
                if !appModel.eventLog.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Label("\(appModel.eventLog.count) events",
                              systemImage: "list.number")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 380)
    }
}

private struct EventWindowRow: View {
    let event: DetectionEvent

    private var color: Color {
        switch event.type {
        case .elevated:  return .yellow
        case .alert:     return .orange
        case .emergency: return .red
        }
    }
    private var icon: String {
        switch event.type {
        case .elevated:  return "exclamationmark.triangle.fill"
        case .alert:     return "bolt.fill"
        case .emergency: return "cross.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(event.type.rawValue).font(.headline)
                Text(event.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(event.probabilityPercent)
                    .font(.title2.bold())
                    .foregroundStyle(color)
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(String(format: "%.0f bpm", event.heartRate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview(windowStyle: .automatic) {
    EventLogWindowView()
        .environment(AppModel())
}
