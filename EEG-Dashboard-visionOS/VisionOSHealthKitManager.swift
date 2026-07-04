//
//  VisionOSHealthKitManager.swift
//  EEG-Dashboard-visionOS
//
//  Reads heart rate and HRV from the shared HealthKit store.
//  visionOS cannot record sensor data itself, but it can read samples that
//  the paired iPhone or Apple Watch has already written — the store is shared
//  across devices via iCloud.
//
//  Uses HKObserverQuery so the values refresh whenever the Watch/iPhone
//  writes a new sample without any polling.

import Foundation
import HealthKit

@MainActor
@Observable
class VisionOSHealthKitManager {

    // MARK: - Published state

    var heartRate:  Double? = nil
    var hrv:        Double? = nil
    var isAuthorized       = false
    var authorizationError: String? = nil

    // MARK: - Private

    private let store  = HKHealthStore()
    private var activeQueries: [HKQuery] = []

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "HealthKit is not available on this device."
            return
        }

        let hrType  = HKQuantityType(.heartRate)
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let read: Set<HKObjectType> = [hrType, hrvType]

        do {
            try await store.requestAuthorization(toShare: [], read: read)
            isAuthorized = true
            startObserving()
        } catch {
            authorizationError = error.localizedDescription
        }
    }

    // MARK: - Observation

    private func startObserving() {
        observe(.heartRate,              unit: .count().unitDivided(by: .minute())) { [weak self] v in self?.heartRate = v }
        observe(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))         { [weak self] v in self?.hrv = v }
    }

    private func observe(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        onUpdate: @escaping @MainActor (Double) -> Void
    ) {
        let type = HKQuantityType(identifier)

        // Fetch the latest existing sample immediately
        fetchLatest(type: type, unit: unit, onUpdate: onUpdate)

        // Then watch for new samples
        let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            self?.fetchLatest(type: type, unit: unit, onUpdate: onUpdate)
        }
        store.execute(observer)
        activeQueries.append(observer)
    }

    private func fetchLatest(
        type: HKQuantityType,
        unit: HKUnit,
        onUpdate: @escaping @MainActor (Double) -> Void
    ) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type,
                                   predicate: nil,
                                   limit: 1,
                                   sortDescriptors: [sort]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let value = sample.quantity.doubleValue(for: unit)
            Task { @MainActor in onUpdate(value) }
        }
        store.execute(query)
    }

    // MARK: - Cleanup

    func stopObserving() {
        activeQueries.forEach { store.stop($0) }
        activeQueries = []
    }
}
