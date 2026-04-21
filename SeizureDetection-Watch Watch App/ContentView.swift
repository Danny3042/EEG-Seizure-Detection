//
//  ContentView.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// Main iOS UI — probability bar, status, start/stop
struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sessionManager: PhoneSessionManager
    @State private var showingEventLog = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status Header
                VStack(spacing: 8) {
                    Text("Seizure Detection")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                }
                .padding(.top, 40)
                
                // Probability Bar
                VStack(spacing: 12) {
                    Text("Risk Level")
                        .font(.headline)
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 60)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(probabilityGradient)
                            .frame(width: geometry(for: probability), height: 60)
                            .animation(.easeInOut, value: probability)
                        
                        HStack {
                            Spacer()
                            Text(String(format: "%.0f%%", probability * 100))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                }
                
                // Health Metrics
                VStack(spacing: 16) {
                    if let heartRate = healthKitManager.heartRate {
                        MetricCard(
                            icon: "heart.fill",
                            value: "\(heartRate)",
                            unit: "BPM",
                            color: .red
                        )
                    }
                    
                    if let hrv = healthKitManager.hrv {
                        MetricCard(
                            icon: "waveform.path.ecg",
                            value: String(format: "%.1f", hrv),
                            unit: "ms",
                            color: .blue
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Navigation to Event Log
                Button(action: { showingEventLog = true }) {
                    Label("View Event Log", systemImage: "list.bullet")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .navigationDestination(isPresented: $showingEventLog) {
                EventLogView()
            }
        }
    }
    
    private var probability: Double {
        healthKitManager.epilepsyPredictionValue ?? 0.0
    }
    
    private var statusColor: Color {
        if let risk = healthKitManager.seizureRisk, risk {
            return .red
        }
        return .green
    }
    
    private var statusText: String {
        if let risk = healthKitManager.seizureRisk, risk {
            return "Seizure Risk Detected"
        }
        return sessionManager.isWatchReachable ? "Monitoring Active" : "Watch Not Connected"
    }
    
    private var probabilityGradient: LinearGradient {
        if probability < 0.3 {
            return LinearGradient(colors: [.green], startPoint: .leading, endPoint: .trailing)
        } else if probability < 0.7 {
            return LinearGradient(colors: [.orange], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private func geometry(for value: Double) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 32
        return CGFloat(value) * screenWidth
    }
}

struct MetricCard: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
                .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(PhoneSessionManager())
}
