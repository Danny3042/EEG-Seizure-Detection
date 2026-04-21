//
//  EEGSeizureDetectionApp.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// @main entry point for iOS app
@main
struct EEGSeizureDetectionApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var sessionManager = PhoneSessionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(sessionManager)
                .onAppear {
                    healthKitManager.requestAuthorization()
                    sessionManager.activateSession()
                }
        }
    }
}
