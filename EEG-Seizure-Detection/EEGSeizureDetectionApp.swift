//
//  EEGSeizureDetectionApp.swift
//  EEGSeizureDetection
//

import SwiftUI

@main
struct EEGSeizureDetectionApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var sessionManager   = PhoneSessionManager()
    @State       private var appModel         = AppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(healthKitManager)
                .environmentObject(sessionManager)
                .environment(appModel)
                .onAppear {
                    healthKitManager.requestAuthorization()
                    sessionManager.activateSession()
                    // Forward Watch events into AppModel so DashboardView logs them
                    sessionManager.appModel = appModel
                }
        }
    }
}
