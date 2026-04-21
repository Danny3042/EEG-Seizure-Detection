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
                Image(systemName: event.isAlert ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(event.isAlert ? .red : .green)
                
                Text(event.state.rawValue.capitalized)
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
                
                if let hr = event.heartRate {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        Text("\(hr) BPM")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        EventLogView()
            .environmentObject(PhoneSessionManager())
    }
}
