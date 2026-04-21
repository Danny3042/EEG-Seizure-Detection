//
//  SeizureDetectionModel.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import CoreML

/// CoreML inference wrapper for seizure detection
class SeizureDetectionModel {
    private var model: MLModel?
    
    init() {
        // Load your CoreML model here
        // model = try? YourMLModel(configuration: MLModelConfiguration()).model
    }
    
    /// Performs prediction on EEG data
    /// - Parameter input: EEG data as MLMultiArray
    /// - Returns: DetectionResult with probability and state
    func predict(input: MLMultiArray) throws -> DetectionResult {
        // Implement CoreML prediction logic
        // This is a placeholder implementation
        let probability = 0.0
        let state = DetectionState.normal
        return DetectionResult(probability: probability, state: state, timestamp: Date())
    }
}

/// Represents the current detection state
enum DetectionState: String, Codable {
    case normal
    case warning
    case seizure
}

/// Result from seizure detection model
struct DetectionResult: Identifiable, Codable {
    let id = UUID()
    let probability: Double
    let state: DetectionState
    let timestamp: Date
}
