//
//  EEGDashboardApp.swift
//  EEG-Dashboard-visionOS
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// @main entry point, WindowGroup + ImmersiveSpace scene setup
@main
struct EEGDashboardApp: App {
    @StateObject private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(appModel)
        }
        .defaultSize(width: 1200, height: 800)
        
        ImmersiveSpace(id: "ImmersiveEEG") {
            EEGImmersiveView()
                .environmentObject(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
