//
//  SettingsView.swift
//  EEGSeizureDetection
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sessionManager:   PhoneSessionManager
    @ObservedObject private var contact = EmergencyContactManager.shared

    @AppStorage("detectionSensitivity") private var sensitivity = "Balanced"
    private let sensitivityOptions = ["Conservative", "Balanced", "Aggressive"]

    private var isConnected: Bool {
        sessionManager.isWatchPaired && sessionManager.isWatchAppInstalled
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $contact.contactName)
                    TextField("Phone number", text: $contact.contactPhone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Emergency Contact")
                } footer: {
                    Text("When a seizure emergency is detected, you'll be prompted to send an SMS alert to this contact.")
                }

                Section {
                    Picker("Sensitivity", selection: $sensitivity) {
                        ForEach(sensitivityOptions, id: \.self) { Text($0) }
                    }
                } header: {
                    Text("Detection")
                } footer: {
                    Text("Aggressive flags more borderline events; Conservative reduces false positives.")
                }

                Section("Apple Watch") {
                    HStack {
                        Label("Connectivity", systemImage: "applewatch")
                        Spacer()
                        Text(isConnected ? "Connected" : "Offline")
                            .foregroundStyle(isConnected ? .green : .red)
                    }
                    HStack {
                        Label("Live", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text(sessionManager.isWatchReachable ? "Reachable now" : "Backgrounded")
                            .foregroundStyle(.secondary)
                    }
                    if let battery = sessionManager.watchBatteryLevel {
                        HStack {
                            Label("Battery", systemImage: "battery.100percent")
                            Spacer()
                            Text("\(Int(battery * 100))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Health Data") {
                    Button("Re-request HealthKit Authorization") {
                        healthKitManager.requestAuthorization()
                    }
                }

                Section {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text("HR + HRV + Motion")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(PhoneSessionManager())
}
