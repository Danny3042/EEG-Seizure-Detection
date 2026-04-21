//
//  DetectionEvent.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation

/// Identifiable event struct, timestamp, probability, HR
struct DetectionEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let state: DetectionState
    let probability: Double
    let heartRate: Int?
    let hrv: Double?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), state: DetectionState, probability: Double, heartRate: Int? = nil, hrv: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.state = state
        self.probability = probability
        self.heartRate = heartRate
        self.hrv = hrv
    }
    
    // Helper properties
    var isAlert: Bool {
        state == .seizure || state == .warning
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        return formatter.string(from: timestamp)
    }
}
