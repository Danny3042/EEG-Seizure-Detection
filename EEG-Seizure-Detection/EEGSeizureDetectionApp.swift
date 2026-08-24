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

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView(isComplete: $hasCompletedOnboarding)
                }
            }
            .environmentObject(healthKitManager)
            .environmentObject(sessionManager)
            .environment(appModel)
            .onAppear {
                // Activating WCSession is cheap and prompt-free — do it immediately
                // so Watch pairing status is accurate even during onboarding.
                sessionManager.activateSession()
                // Forward Watch events into AppModel so DashboardView logs them
                sessionManager.appModel = appModel
                // Localhost bridge to visionOS Simulator — see WatchBridgeServer.swift
                WatchBridgeServer.shared.start()
            }
        }
    }
}
