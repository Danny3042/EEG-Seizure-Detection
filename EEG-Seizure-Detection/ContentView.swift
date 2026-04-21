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
    @State private var isMonitoring = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status Section
                VStack(spacing: 12) {
                    Text("Seizure Detection")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    StatusIndicator(
                        isMonitoring: isMonitoring,
                        seizureRisk: healthKitManager.seizureRisk
                    )
                }
                .padding(.top, 40)
                
                // Probability Display
                if let probability = healthKitManager.epilepsyPredictionValue {
                    ProbabilityView(probability: probability)
                        .padding(.horizontal)
                }
                
                // Health Metrics
                VStack(spacing: 16) {
                    if let heartRate = healthKitManager.heartRate {
                        MetricCard(
                            title: "Heart Rate",
                            value: "\(heartRate)",
                            unit: "BPM",
                            icon: "heart.fill"
                        )
                    }
                    
                    if let hrv = healthKitManager.hrv {
                        MetricCard(
                            title: "HRV",
                            value: String(format: "%.1f", hrv),
                            unit: "ms",
                            icon: "waveform.path.ecg"
                        )
                    }
                    
                    MetricCard(
                        title: "Activity",
                        value: activityDescription,
                        unit: "",
                        icon: "figure.walk"
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Control Button
                Button(action: toggleMonitoring) {
                    HStack {
                        Image(systemName: isMonitoring ? "stop.fill" : "play.fill")
                        Text(isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isMonitoring ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Event Log Navigation
                NavigationLink(destination: EventLogView()) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("View Event Log")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var activityDescription: String {
        switch healthKitManager.activity {
        case "0": return "Stationary"
        case "1": return "Walking"
        case "3": return "Running"
        default: return "Unknown"
        }
    }
    
    private func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            healthKitManager.startMonitoringActivity()
        }
    }
}

// MARK: - Supporting Views

struct StatusIndicator: View {
    let isMonitoring: Bool
    let seizureRisk: Bool?
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            Text(statusText)
                .font(.headline)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var statusColor: Color {
        if !isMonitoring {
            return .gray
        }
        
        if let risk = seizureRisk, risk {
            return .red
        }
        
        return .green
    }
    
    private var statusText: String {
        if !isMonitoring {
            return "Not Monitoring"
        }
        
        if let risk = seizureRisk, risk {
            return "Seizure Risk Detected"
        }
        
        return "Normal"
    }
}

struct ProbabilityView: View {
    let probability: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Seizure Probability")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f%%", probability * 100))
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(probabilityColor)
                        .frame(width: geometry.size.width * probability)
                }
            }
            .frame(height: 20)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
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
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(PhoneSessionManager())
}

