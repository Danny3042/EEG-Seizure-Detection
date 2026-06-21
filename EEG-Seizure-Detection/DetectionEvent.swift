// Shared/DetectionEvent.swift — tick all three targets

import Foundation

struct DetectionEvent: Identifiable, Codable {
    let id:           UUID
    let timestamp:    Date
    let probability:  Double
    let heartRate:    Double
    let type:         EventType
    let batteryLevel: Float?   // Watch battery 0–1 at detection time; nil if unavailable

    enum EventType: String, Codable {
        case elevated  = "Elevated"
        case alert     = "Alert"
        case emergency = "Emergency"
    }

    init(probability: Double, heartRate: Double, type: EventType, batteryLevel: Float? = nil) {
        self.id           = UUID()
        self.timestamp    = Date()
        self.probability  = probability
        self.heartRate    = heartRate
        self.type         = type
        self.batteryLevel = batteryLevel
    }

    var formattedTime: String {
        timestamp.formatted(date: .abbreviated, time: .standard)
    }

    var probabilityPercent: String {
        String(format: "%.0f%%", probability * 100)
    }

    // Serialise for WatchConnectivity message
    var asMessage: [String: Any] {
        ["type":        type.rawValue,
         "probability": probability,
         "heartRate":   heartRate,
         "timestamp":   timestamp.timeIntervalSince1970]
    }

    static func from(message: [String: Any]) -> DetectionEvent? {
        guard let typeStr = message["type"] as? String,
              let type  = EventType(rawValue: typeStr),
              let prob  = message["probability"] as? Double,
              let hr    = message["heartRate"] as? Double
        else { return nil }
        return DetectionEvent(probability: prob, heartRate: hr, type: type, batteryLevel: nil)
    }
}
