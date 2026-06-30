//
//  RootTabView.swift
//  EEGSeizureDetection
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Dashboard", systemImage: "waveform.path.ecg.text.clipboard") }

            NavigationStack { EventLogView() }
                .tabItem { Label("History", systemImage: "chart.bar.fill") }

            JournalView()
                .tabItem { Label("Journal", systemImage: "doc.text.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(PhoneSessionManager())
}
