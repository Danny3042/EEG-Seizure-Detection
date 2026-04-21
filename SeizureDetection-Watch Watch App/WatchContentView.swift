//
//  WatchContentView.swift
//  SeizureDetection-Watch Watch App
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// Status ring, probability display, start/stop button
struct WatchContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sessionManager: WatchSessionManager
    @State private var isMonitoring = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: probability)
                        .stroke(probabilityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: probability)
                    
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f%%", probability * 100))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Risk")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
                
                // Status Text
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .multilineTextAlignment(.center)
                
                // Health Metrics
                VStack(spacing: 8) {
                    if let heartRate = healthKitManager.heartRate {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("\(heartRate)")
                                .font(.headline)
                            Text("BPM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    if let hrv = healthKitManager.hrv {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(.blue)
                            Text(String(format: "%.1f", hrv))
                                .font(.headline)
                            Text("ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 8)
                
                // Control Button
                Button(action: toggleMonitoring) {
                    Label(
                        isMonitoring ? "Stop" : "Start",
                        systemImage: isMonitoring ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(isMonitoring ? .red : .green)
            }
            .padding()
        }
    }
    
    private var probability: Double {
        healthKitManager.epilepsyPredictionValue ?? 0.0
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
    
    private var statusColor: Color {
        if !isMonitoring {
            return .gray
        }
        
        if let risk = healthKitManager.seizureRisk, risk {
            return .red
        }
        
        return .green
    }
    
    private var statusText: String {
        if !isMonitoring {
            return "Monitoring Stopped"
        }
        
        if let risk = healthKitManager.seizureRisk, risk {
            return "Seizure Risk Detected"
        }
        
        return "Normal Activity"
    }
    
    private func toggleMonitoring() {
        isMonitoring.toggle()
        
        if isMonitoring {
            healthKitManager.startMonitoringActivity()
        }
        
        // Send status to phone
        sessionManager.sendMonitoringStatus(isMonitoring: isMonitoring)
    }
}

#Preview {
    WatchContentView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(WatchSessionManager())
}
