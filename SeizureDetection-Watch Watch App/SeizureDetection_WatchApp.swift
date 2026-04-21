//
//  SeizureDetection_WatchApp.swift
//  SeizureDetection-Watch Watch App
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// @main entry point for Watch app
@main
struct SeizureDetectionWatchApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var sessionManager = WatchSessionManager()
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(healthKitManager)
                .environmentObject(sessionManager)
                .onAppear {
                    healthKitManager.requestAuthorization()
                    healthKitManager.startMonitoringActivity()
                    sessionManager.activateSession()
                }
        }
    }
}
