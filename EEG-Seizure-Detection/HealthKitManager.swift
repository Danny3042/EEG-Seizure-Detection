//
//  HealthKitManager.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//


import SwiftUI
import Combine
import HealthKit
import CoreMotion
import CoreML


// Manager class to handle HealthKit and motion activity updates
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore() // Interface to interact with HealthKit
    private let motionManager = CMMotionActivityManager() // Interface to interact with motion activity

    @Published var seizureRisk: Bool?
    @Published var heartRate: Int? // Stores the latest heart rate
    @Published var hrv: Double? // Stores the latest HRV
    @Published var activity: String = "Unknown" // Stores the current activity description (e.g., walking, running)
    @Published var epilepsyPredictionValue: Double? = nil

    static let shared = HealthKitManager() // Singleton instance
    
    
    ///
    
    
    
    
    // Fetch heart rate from HealthKit
    func fetchHeartRate(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(.failure(NSError(domain: "HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Heart rate type not available"])))
            return
        }

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let sample = samples?.first as? HKQuantitySample {
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                let heartRate = Int(sample.quantity.doubleValue(for: heartRateUnit))
                completion(.success(heartRate))
            } else {
                completion(.failure(NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "No heart rate data available"])))
            }
        }
        healthStore.execute(query)
    }

    // Fetch HRV from HealthKit
    func fetchHRV(completion: @escaping (Result<Double, Error>) -> Void) {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(.failure(NSError(domain: "HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "HRV type not available"])))
            return
        }

        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let sample = samples?.first as? HKQuantitySample {
                let hrvUnit = HKUnit.secondUnit(with: .milli)
                let hrv = sample.quantity.doubleValue(for: hrvUnit)
                completion(.success(hrv))
            } else {
                completion(.failure(NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "No HRV data available"])))
            }
        }
        healthStore.execute(query)
    }
    
    
    ///
    
    // Request authorization to access HealthKit data
    func requestAuthorization() {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }

        // Define which HealthKit data types we want to read
        let readDataTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!, // Heart rate
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)! // Heart rate variability (HRV)
        ]

        // Request authorization from the user
        healthStore.requestAuthorization(toShare: nil, read: readDataTypes) { success, error in
            if let error = error {
                print("Error requesting authorization: \(error.localizedDescription)") // Log any errors
                return
            }

            print("Authorization successful: \(success)")
            
            // If authorization is granted, start fetching heart rate and HRV data
            if success {
                self.startHeartRateObserverQuery()
                self.startHRVObserverQuery()
            }
        }
    }
    
    // Start observing heart rate updates
    private func startHeartRateObserverQuery() {
        // Define the heart rate data type
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("Failed to create heart rate type")
            return
        }
        
        // Create an observer query to monitor changes to heart rate
        let heartRateQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Observer query error: \(error.localizedDescription)")
                return
            }
            
            // When triggered, fetch the latest heart rate sample
            self?.fetchLatestHeartRateSample()
        }
        
        // Execute the observer query
        healthStore.execute(heartRateQuery)
    }
    
    // Fetch the most recent heart rate sample
    private func fetchLatestHeartRateSample() {
        // Define the heart rate data type
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("Failed to create heart rate type for fetching samples")
            return
        }
        
        // Sort the samples by most recent
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let heartRateSampleQuery = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1, // Fetch only the latest sample
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                print("Error fetching heart rate sample: \(error.localizedDescription)")
                return
            }
            
            // Extract the heart rate value from the sample
            if let heartRateSample = samples?.first as? HKQuantitySample {
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute()) // Unit: beats per minute
                let heartRateValue = Int(heartRateSample.quantity.doubleValue(for: heartRateUnit)) // Convert to Int
                
                DispatchQueue.main.async {
                    self?.heartRate = heartRateValue // Update the heart rate
                    self?.predictEpilepsyFromManager() //
                }
            }
        }
        
        // Execute the sample query
        healthStore.execute(heartRateSampleQuery)
    }
    
    // Start observing HRV updates
    private func startHRVObserverQuery() {
        // Define the HRV data type
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            print("Failed to create HRV type")
            return
        }
        
        // Create an observer query to monitor changes to HRV
        let hrvQuery = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Observer query error: \(error.localizedDescription)")
                return
            }
            
            // When triggered, fetch the latest HRV sample
            self?.fetchLatestHRVSample()
            
        }
        
        // Execute the observer query
        healthStore.execute(hrvQuery)
    }
    
    // Fetch the most recent HRV sample
    private func fetchLatestHRVSample() {
        // Define the HRV data type
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            print("Failed to create HRV type for fetching samples")
            return
        }
        
        // Sort the samples by most recent
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let hrvSampleQuery = HKSampleQuery(
            sampleType: hrvType,
            predicate: nil,
            limit: 1, // Fetch only the latest sample
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                print("Error fetching HRV sample: \(error.localizedDescription)")
                return
            }
            
            // Extract the HRV value from the sample
            if let hrvSample = samples?.first as? HKQuantitySample {
                let hrvUnit = HKUnit.secondUnit(with: .milli) // Unit: milliseconds
                let hrvValue = hrvSample.quantity.doubleValue(for: hrvUnit) // Convert to Double
                
                DispatchQueue.main.async {
                    self?.hrv = hrvValue // Update the HRV
                    self?.predictEpilepsyFromManager()
                }
            }
        }
        
        // Execute the sample query
        healthStore.execute(hrvSampleQuery)
    }
    
    // Start monitoring motion activity (e.g., walking, running)
    func startMonitoringActivity() {
        // Check if motion activity is available on this device
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Motion activity is not available")
            return
        }
        
        // Start receiving motion activity updates
        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            
            DispatchQueue.main.async {
                // Update the activity description based on the detected motion
                if activity.walking {
                    self?.activity = "1"
                } else if activity.running {
                    self?.activity = "3"
                } else if activity.automotive {
                    self?.activity = "0"
                } else if activity.stationary {
                    self?.activity = "0"
                } else {
                    self?.activity = "0"
                }
                
                self?.predictEpilepsyFromManager()
            }
        }
    }
    
    func predictEpilepsyFromManager() {
           guard let heartRate = self.heartRate,
                 let hrv = self.hrv,
                 let activityInt = Int64(self.activity) else {
               print("Values not ready for prediction")
               return
           }

           // Assuming the model returns a probability or a score as a Double
           if let predictionValue = PredictionManager.predictEpilepsy(heartRate: Double(heartRate), hrv: hrv, activity: activityInt) {
               DispatchQueue.main.async {
                   self.epilepsyPredictionValue = predictionValue // Set as Double
               }
               print("Prediction value: \(predictionValue)")
               if predictionValue >= 0.5 {
                   seizureRisk = true
                   print("Seizure risk : \(seizureRisk ?? false)")
               }
           }
       }
}
