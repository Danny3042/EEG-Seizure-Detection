//
//  notification.swift
//  SeizureDetection-Watch Watch App
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI
import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    // Request notification permissions
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            } else if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied")
            }
        }
    }

    // Schedule a notification
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}


///*Notification Texts:
///-High Heart Rate: "Hey there! Your heart rate seems a bit high. Take a moment to relax "
///-Low HRV: "Heads up! Your body might need some rest. Take it easy "
///-High Seizure Risk: "You’re showing signs of stress. Stay safe and let someone nearby know "

// VitalSignsMonitor manages health data and checks for abnormal readings
class VitalSignsMonitor {
    // Observable HealthKit manager to fetch health data
    @StateObject private var healthKitManager = HealthKitManager()

    // Vital signs variables
    var heartRate: Int? // Heart rate in bpm
    var hrv: Int?       // Heart rate variability in milliseconds
    var seizureRisk: Bool = true // Static for now but can use custom detection logic

    static let shared = VitalSignsMonitor() // Singleton instance

    // Fetch and update vital signs (Heart Rate and HRV)
    func fetchAndUpdateVitalSigns() {
        // Fetch heart rate
        HealthKitManager.shared.fetchHeartRate { [weak self] result in
            switch result {
            case .success(let heartRate):
                self?.heartRate = heartRate
                print("Heart Rate Updated: \(heartRate)")
            case .failure(let error):
                print("Failed to fetch heart rate: \(error.localizedDescription)")
            }
        }

        // Fetch HRV
        HealthKitManager.shared.fetchHRV { [weak self] result in
            switch result {
            case .success(let hrv):
                self?.hrv = Int(hrv) // Convert HRV to integer if needed
                print("HRV Updated: \(hrv)")
            case .failure(let error):
                print("Failed to fetch HRV: \(error.localizedDescription)")
            }
        }
    }

    // Check vital signs and send notifications if any thresholds are exceeded
    func checkVitalSigns() {
        if let heartRate = heartRate, heartRate > 100 {
            NotificationManager.shared.sendNotification(
                title: "Heart Rate Alert",
                body: "Hey there! Your heart rate seems a bit high. Take a moment to relax"
            )
        }
        if let hrv = hrv, hrv < 40 {
            NotificationManager.shared.sendNotification(
                title: "HRV Alert",
                body: "Heads up! Your body might need some rest. Take it easy"
            )
        }
        if seizureRisk {
            NotificationManager.shared.sendNotification(
                title: "Seizure Alert",
                body: "You’re showing signs of stress. Stay safe and let someone nearby know"
            )
        }
    }

    // Start monitoring vital signs on a timer
    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.fetchAndUpdateVitalSigns() // Fetch the latest health data
            self.checkVitalSigns()         // Check for abnormalities
        }
    }
}
