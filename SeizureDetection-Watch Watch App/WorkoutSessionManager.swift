//
//  WorkoutSessionManager.swift
//  SeizureDetection-Watch Watch App
//
//  watchOS suspends an app within seconds of backgrounding unless it holds
//  an HKWorkoutSession — that's the only API that grants extended background
//  CPU time. Starting one (even with a non-exercise .other activity type)
//  keeps monitoring/demo ticks firing and WatchConnectivity reachable while
//  the wrist drops or the app isn't on screen.

import Foundation
import HealthKit
import Combine

class WorkoutSessionManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var isActive = false
    @Published var authorizationDenied = false

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]
        healthStore.requestAuthorization(toShare: share, read: read) { [weak self] success, _ in
            DispatchQueue.main.async { self?.authorizationDenied = !success }
        }
    }

    func start() {
        guard session == nil else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        do {
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                              workoutConfiguration: config)
            newSession.delegate = self
            newBuilder.delegate = self

            session = newSession
            builder = newBuilder

            let startDate = Date()
            newSession.startActivity(with: startDate)
            newBuilder.beginCollection(withStart: startDate) { _, _ in }
        } catch {
            print("WorkoutSessionManager start error: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard let session, let builder else { return }
        session.end()
        builder.endCollection(withEnd: Date()) { _, _ in
            builder.finishWorkout { _, _ in }
        }
        self.session = nil
        self.builder = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                         didChangeTo toState: HKWorkoutSessionState,
                         from fromState: HKWorkoutSessionState,
                         date: Date) {
        DispatchQueue.main.async { self.isActive = (toState == .running) }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("WorkoutSession failed: \(error.localizedDescription)")
        DispatchQueue.main.async { self.isActive = false }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                         didCollectDataOf collectedTypes: Set<HKSampleType>) {}
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
