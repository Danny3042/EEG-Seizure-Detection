//
//  CloudKitBridge.swift
//  EEGSeizureDetection
//
//  Relays the Watch's live pIctal stream and detection events to CloudKit's
//  private database, so the visionOS app — which WatchConnectivity can't
//  reach directly — can pick them up on the same iCloud account.
//
//  Requires a paid Apple Developer Program membership (CloudKit is not
//  available to free/personal-team signing) and the same iCloud account
//  signed in on every device that should sync.

import Foundation
import Combine
import CloudKit

let watchBridgeContainerID = "iCloud.danielramzani.EEG-Seizure-Detection"

// MARK: - Record schema

enum CloudRecordType {
    static let liveState = "WatchLiveState"
    static let event      = "SeizureEvent"
}

// A single well-known record holds the latest live snapshot — cheaper and
// simpler than a growing table when only the most recent value matters.
private let liveStateRecordID = CKRecord.ID(recordName: "liveState")

@MainActor
final class CloudKitBridge: ObservableObject {

    @Published var isAvailable = false
    @Published var lastError: String? = nil

    private let container = CKContainer(identifier: watchBridgeContainerID)
    private lazy var database = container.privateCloudDatabase

    private var lastLivePush = Date.distantPast
    private let liveThrottle: TimeInterval = 2.0

    init() {
        Task { await checkAccountStatus() }
    }

    private func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            isAvailable = (status == .available)
            if status != .available {
                lastError = "Sign in to iCloud in Settings to sync with visionOS."
            }
        } catch {
            isAvailable = false
            lastError = error.localizedDescription
        }
    }

    // MARK: - Live state

    /// Overwrites the singleton live-state record. Throttled client-side so
    /// a 1 Hz Watch stream doesn't hammer CloudKit's request quota.
    func pushLiveState(probability: Double, heartRate: Int?, hrv: Double?, battery: Float?) {
        let now = Date()
        guard now.timeIntervalSince(lastLivePush) >= liveThrottle else { return }
        lastLivePush = now

        let record = CKRecord(recordType: CloudRecordType.liveState, recordID: liveStateRecordID)
        record["probability"] = probability
        if let heartRate { record["heartRate"] = heartRate }
        if let hrv         { record["hrv"] = hrv }
        if let battery      { record["battery"] = Double(battery) }
        record["updatedAt"] = now

        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .allKeys   // overwrite unconditionally — no fetch-then-save round trip
        op.modifyRecordsResultBlock = { [weak self] result in
            if case .failure(let error) = result {
                Task { @MainActor in self?.lastError = error.localizedDescription }
            }
        }
        database.add(op)
    }

    // MARK: - Events

    /// Saves a detection event as its own record, keyed by the event's UUID
    /// so re-sends (e.g. after a retry) don't create duplicates. The event is
    /// stored as a single encoded blob (matching how it's already round-tripped
    /// over WatchConnectivity) so id/timestamp survive exactly — reconstructing
    /// those from separate fields would stamp a new id and "now" as the time.
    func pushEvent(_ event: DetectionEvent) {
        guard let payload = try? JSONEncoder().encode(event) else { return }
        let recordID = CKRecord.ID(recordName: event.id.uuidString)
        let record = CKRecord(recordType: CloudRecordType.event, recordID: recordID)
        record["payload"] = payload as NSData

        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .allKeys
        op.modifyRecordsResultBlock = { [weak self] result in
            if case .failure(let error) = result {
                Task { @MainActor in self?.lastError = error.localizedDescription }
            }
        }
        database.add(op)
    }
}
