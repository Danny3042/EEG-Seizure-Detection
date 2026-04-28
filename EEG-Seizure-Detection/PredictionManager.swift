//
//  PredictionManager.swift
//  EEG-Seizure-Detection
//
//  Created by Daniel Ramzani on 21/04/2026.
//


import Foundation
import CoreML

class PredictionManager {
    private static let seizureModel = SeizureDetectionModel()
    
    static func predictEpilepsy(heartRate: Double, hrv: Double, activity: Int64) -> Double? {
        do {
            let result = try seizureModel.predict(heartRate: heartRate, hrv: hrv, activity: activity)
            return result.probability
        } catch {
            print("Prediction error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get full detection result including state
    static func predictEpilepsyWithState(heartRate: Double, hrv: Double, activity: Int64) -> DetectionResult? {
        do {
            return try seizureModel.predict(heartRate: heartRate, hrv: hrv, activity: activity)
        } catch {
            print("Prediction error: \(error.localizedDescription)")
            return nil
        }
    }
}
