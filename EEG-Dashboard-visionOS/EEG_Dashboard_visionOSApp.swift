//
//  EEG_Dashboard_visionOSApp.swift
//  EEG-Dashboard-visionOS
//

import SwiftUI

@main
struct EEG_Dashboard_visionOSApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {

        // ── Main 2-D dashboard ────────────────────────────────────────────
        WindowGroup(id: "main") {
            DashboardView()
                .environment(appModel)
                .onAppear {
                    appModel.requestHealthKitAuthorization()
                    appModel.startWatchBridgeSync()
                }
        }
        .defaultSize(width: 920, height: 720)

        // ── 3-D EEG brain map — volumetric window ─────────────────────────
        WindowGroup(id: appModel.immersiveSpaceID) {
            EEGImmersiveView()
                .environment(appModel)
                .onAppear   { appModel.immersiveSpaceState = .open   }
                .onDisappear { appModel.immersiveSpaceState = .closed }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.7, height: 0.7, depth: 0.7, in: .meters)

        // ── Probability timeline — floating chart ─────────────────────────
        WindowGroup(id: "timeline") {
            ProbabilityTimelineView()
                .environment(appModel)
        }
        .defaultSize(width: 700, height: 320)

        // ── Event log — spatial history panel ────────────────────────────
        WindowGroup(id: "eventlog") {
            EventLogWindowView()
                .environment(appModel)
        }
        .defaultSize(width: 540, height: 500)

        // ── Spike train raster — 22-channel raster plot ───────────────────
        WindowGroup(id: "spiketrain") {
            SpikeTrainView()
                .environment(appModel)
        }
        .defaultSize(width: 820, height: 620)
    }
}
