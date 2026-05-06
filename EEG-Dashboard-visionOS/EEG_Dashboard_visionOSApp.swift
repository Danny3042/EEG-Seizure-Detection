//
//  EEG_Dashboard_visionOSApp.swift
//  EEG-Dashboard-visionOS
//

import SwiftUI

@main
struct EEG_Dashboard_visionOSApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {

        // ── Main 2-D control panel ────────────────────────────────────────
        WindowGroup(id: "main") {
            DashboardView()
                .environment(appModel)
        }

        // ── 3-D EEG brain map — volumetric window ─────────────────────────
        // A volume keeps the real environment fully visible, lets the user
        // reach in and tap electrode orbs, and hides the flat dashboard.
        WindowGroup(id: appModel.immersiveSpaceID) {
            EEGImmersiveView()
                .environment(appModel)
                .onAppear   { appModel.immersiveSpaceState = .open   }
                .onDisappear { appModel.immersiveSpaceState = .closed }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.7, height: 0.7, depth: 0.7, in: .meters)
    }
}
