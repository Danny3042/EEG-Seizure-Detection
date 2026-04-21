//
//  PredictionManager.swift
//  EEG-Seizure-Detection
//
//  Created by Daniel Ramzani on 21/04/2026.
//


import Foundation
import CoreML

class PredictionManager {
    static func predictEpilepsy(heartRate: Double, hrv: Double, activity: Int64) -> Double? {
        do {
            let config = MLModelConfiguration()
            let model = try HR_HRV_(configuration: config)
            
            let prediction = try model.prediction(heart_rate: heartRate, HRV: hrv, Activity: activity)
            
            return prediction.label
        } catch {
             print("Prediction error: \(error.localizedDescription)")
            return 9
        }
    }
}