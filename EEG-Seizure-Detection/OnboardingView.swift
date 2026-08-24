//
//  OnboardingView.swift
//  EEGSeizureDetection
//
//  First-run flow: explains what the app does, requests HealthKit access
//  in context (not blind on launch), surfaces Watch pairing, and offers to
//  set up an emergency contact before landing on the dashboard.

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var sessionManager:   PhoneSessionManager
    @ObservedObject    private var contact = EmergencyContactManager.shared

    @Binding var isComplete: Bool

    @State private var page = 0
    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                WelcomePage()
                    .tag(0)
                HealthKitPage(healthKitManager: healthKitManager)
                    .tag(1)
                WatchPage(sessionManager: sessionManager)
                    .tag(2)
                EmergencyContactPage(contact: contact)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            pageIndicator

            controls
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: i == page ? 20 : 6, height: 6)
                    .animation(.easeInOut, value: page)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack {
            if page > 0 {
                Button("Back") { withAnimation { page -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if page < totalPages - 1 {
                Button(page == 1 ? "Allow & Continue" : "Continue") {
                    if page == 1 { healthKitManager.requestAuthorization() }
                    withAnimation { page += 1 }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    isComplete = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        OnboardingPage(
            icon: "waveform.path.ecg.text.clipboard",
            iconColor: .blue,
            title: "EEG Seizure Detection",
            description: "Your Apple Watch continuously monitors heart rate and motion to estimate seizure risk in real time. This app shows you that risk, keeps a history of detected events, and can alert a caregiver when it matters most."
        )
    }
}

// MARK: - Page 2: HealthKit

private struct HealthKitPage: View {
    @ObservedObject var healthKitManager: HealthKitManager

    var body: some View {
        OnboardingPage(
            icon: "heart.text.square.fill",
            iconColor: .red,
            title: "Health Data Access",
            description: "We read heart rate and heart-rate variability from Health to power the on-device prediction model. This data never leaves your devices and is never shared with third parties."
        )
    }
}

// MARK: - Page 3: Watch

private struct WatchPage: View {
    @ObservedObject var sessionManager: PhoneSessionManager

    private var isConnected: Bool {
        #if os(iOS)
        sessionManager.isWatchPaired && sessionManager.isWatchAppInstalled
        #else
        sessionManager.isWatchReachable
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingPage(
                icon: "applewatch",
                iconColor: .green,
                title: "Apple Watch Is the Sensor",
                description: "The Watch has the best hardware for this job — it stays in contact with your skin and runs the detection model continuously in the background, even when the Watch app isn't on screen."
            )

            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Apple Watch connected" : "No Apple Watch detected yet — that's OK, you can pair one later")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
        }
    }
}

// MARK: - Page 4: Emergency contact

private struct EmergencyContactPage: View {
    @ObservedObject var contact: EmergencyContactManager

    var body: some View {
        VStack(spacing: 24) {
            OnboardingPage(
                icon: "person.crop.circle.badge.exclamationmark",
                iconColor: .orange,
                title: "Emergency Contact",
                description: "Optional, but recommended. When a high-risk event is detected, you'll be prompted to send an SMS alert to this person. You can set this up later in Settings if you'd rather skip it now."
            )

            VStack(spacing: 12) {
                TextField("Contact name", text: $contact.contactName)
                    .textFieldStyle(.roundedBorder)
                TextField("Phone number", text: $contact.contactPhone)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Shared page layout

private struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
        .environmentObject(HealthKitManager.shared)
        .environmentObject(PhoneSessionManager())
}
