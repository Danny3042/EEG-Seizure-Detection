//
//  SeizureDetectionModel.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import CoreML

// Note: DetectionState enum should be defined in DetectionState.swift
// and included in the same target as this file

/// CoreML inference wrapper for seizure detection
class SeizureDetectionModel {
    private var model: MLModel?
    
    init() {
        // Load your CoreML model here
        // Uncomment and replace with your actual model name when you add the .mlmodel file:
        // do {
        //     let config = MLModelConfiguration()
        //     model = try YourModelName(configuration: config).model
        // } catch {
        //     print("Failed to load model: \(error)")
        // }
    }
    
    /// Performs prediction on health data (heart rate, HRV, activity)
    /// - Parameters:
    ///   - heartRate: Heart rate in BPM
    ///   - hrv: Heart rate variability
    ///   - activity: Activity level
    /// - Returns: DetectionResult with probability and state
    func predict(heartRate: Double, hrv: Double, activity: Int64) throws -> DetectionResult {
        guard let model = model else {
            throw NSError(domain: "SeizureDetection", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        // TODO: Replace this with actual CoreML prediction once model is properly loaded
        // Example implementation (adjust based on your actual model's input/output):
        // let input = YourModelInput(heart_rate: heartRate, HRV: hrv, Activity: activity)
        // let output = try model.prediction(from: input)
        // let probability = output.probability
        
        // Placeholder implementation
        let probability = 0.0
        let state: DetectionState = probability > 0.7 ? .seizure : (probability > 0.4 ? .warning : .normal)
        
        return DetectionResult(probability: probability, state: state, timestamp: Date())
    }
    
    /// Performs prediction on EEG data (legacy method)
    /// - Parameter input: EEG data as MLMultiArray
    /// - Returns: DetectionResult with probability and state
    func predict(input: MLMultiArray) throws -> DetectionResult {
        guard let model = model else {
            throw NSError(domain: "SeizureDetection", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        // Implement CoreML prediction logic for EEG data
        let probability = 0.0
        let state = DetectionState.normal
        return DetectionResult(probability: probability, state: state, timestamp: Date())
    }
}

/// Result from seizure detection model
struct DetectionResult: Identifiable, Codable {
    let id: UUID
    let probability: Double
    let state: DetectionState
    let timestamp: Date
    
    init(probability: Double, state: DetectionState, timestamp: Date) {
        self.id = UUID()
        self.probability = probability
        self.state = state
        self.timestamp = timestamp
    }
    
    // Custom Codable implementation to handle UUID
    enum CodingKeys: String, CodingKey {
        case id, probability, state, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        probability = try container.decode(Double.self, forKey: .probability)
        state = try container.decode(DetectionState.self, forKey: .state)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(probability, forKey: .probability)
        try container.encode(state, forKey: .state)
        try container.encode(timestamp, forKey: .timestamp)
    }
}
