//
//  EEGDashboardApp.swift
//  EEG-Dashboard-visionOS
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// Secondary app configuration (entry point is EEG_Dashboard_visionOSApp).
struct EEGDashboardApp: App {
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .defaultSize(width: 1200, height: 800)
        .environment(appModel)
        
        ImmersiveSpace(id: "ImmersiveEEG") {
            EEGImmersiveView()
        }
        .environment(appModel)
    }
}
