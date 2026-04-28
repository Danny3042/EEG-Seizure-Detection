//
//  EventLogView.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// List of detection events received from Watch via WatchConnectivity
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
                    EventRow(event: event)
                }
            }
        }
        .navigationTitle("Event Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !sessionManager.detectionEvents.isEmpty {
                Button("Clear") {
                    sessionManager.clearEvents()
                }
            }
        }
    }
}

struct EventRow: View {
    let event: DetectionEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbolName)
                    .foregroundColor(symbolColor)
                
                Text(event.type.rawValue)
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: "%.1f%%", event.probability * 100))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(event.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                    Text(String(format: "%.0f BPM", event.heartRate))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var symbolName: String {
        switch event.type {
        case .elevated:
            return "exclamationmark.circle.fill"
        case .alert:
            return "exclamationmark.triangle.fill"
        case .emergency:
            return "exclamationmark.octagon.fill"
        }
    }
    
    private var symbolColor: Color {
        switch event.type {
        case .elevated:
            return .yellow
        case .alert:
            return .orange
        case .emergency:
            return .red
        }
    }
}

#Preview {
    NavigationStack {
        EventLogView()
            .environmentObject(PhoneSessionManager())
    }
}
