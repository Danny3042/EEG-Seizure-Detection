//
//  DashboardView.swift
//  EEG-Dashboard-visionOS
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// Main 2D control panel window — probability gauge, event log, controls
struct DashboardView: View {
    @Environment(AppModel.self) var appModel
    
    #if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    #endif
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Probability Gauge
                    ProbabilityGauge(probability: appModel.seizureProbability)
                        .frame(height: 200)
                        .padding()
                    
                    // Control Buttons
                    HStack(spacing: 16) {
                        #if os(visionOS)
                        Button(action: toggleImmersiveSpace) {
                            Label(
                                appModel.isImmersiveSpaceActive ? "Close 3D View" : "Open 3D View",
                                systemImage: appModel.isImmersiveSpaceActive ? "xmark.circle" : "cube"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        #endif
                        
                        Button(action: toggleSimulation) {
                            Label(
                                "Start Simulation",
                                systemImage: "play.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    // Event Log
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Events")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if appModel.detectionEvents.isEmpty {
                            ContentUnavailableView(
                                "No Events",
                                systemImage: "list.bullet",
                                description: Text("Detection events will appear here")
                            )
                            .frame(height: 200)
                        } else {
                            ForEach(appModel.detectionEvents.prefix(10)) { event in
                                DashboardEventRow(event: event)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Channel Activity Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Channel Activity")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(appModel.channelActivity.prefix(12)) { channel in
                                ChannelActivityCard(channel: channel)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("EEG Seizure Detection")
        }
    }
    
    #if os(visionOS)
    private func toggleImmersiveSpace() {
        Task {
            if appModel.isImmersiveSpaceActive {
                appModel.immersiveSpaceState = .inTransition
                await dismissImmersiveSpace()
                // State will be set to .closed in ImmersiveView.onDisappear
            } else {
                appModel.immersiveSpaceState = .inTransition
                let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                if case .error = result {
                    appModel.immersiveSpaceState = .closed
                } else if case .userCancelled = result {
                    appModel.immersiveSpaceState = .closed
                }
                // State will be set to .open in ImmersiveView.onAppear
            }
        }
    }
    #endif
    
    private func toggleSimulation() {
        appModel.startSimulation()
    }
}

// MARK: - Supporting Views

struct ProbabilityGauge: View {
    let probability: Double
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Seizure Probability")
                .font(.title2)
                .fontWeight(.semibold)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: probability)
                    .stroke(probabilityColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: probability)
                
                VStack(spacing: 4) {
                    Text(String(format: "%.1f%%", probability * 100))
                        .font(.system(size: 48, weight: .bold))
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(probabilityColor)
                }
            }
            .frame(width: 180, height: 180)
        }
    }
    
    private var probabilityColor: Color {
        if probability < 0.3 {
            return .green
        } else if probability < 0.7 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusText: String {
        if probability < 0.3 {
            return "Normal"
        } else if probability < 0.7 {
            return "Elevated"
        } else {
            return "High Risk"
        }
    }
}

struct DashboardEventRow: View {
    let event: DetectionEvent
    
    var body: some View {
        HStack {
            Image(systemName: isAlert ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isAlert ? .red : .green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.rawValue)
                    .font(.headline)
                
                Text(event.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1f%%", event.probability * 100))
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    private var isAlert: Bool {
        event.type == .alert || event.type == .emergency
    }
}

struct ChannelActivityCard: View {
    let channel: ChannelData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(channel.name)
                .font(.caption)
                .fontWeight(.semibold)
            
            HStack {
                Text(String(format: "%.1f", channel.power))
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Rectangle()
                    .fill(powerColor)
                    .frame(width: 4, height: 30)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
    }
    
    private var powerColor: Color {
        if channel.power < 50 {
            return .green
        } else if channel.power < 100 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppModel())
}
