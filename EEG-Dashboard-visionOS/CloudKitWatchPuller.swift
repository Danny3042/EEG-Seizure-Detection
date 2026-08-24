//
//  CloudKitWatchPuller.swift
//  EEG-Dashboard-visionOS
//
//  Pulls the Watch's live pIctal stream and detection events from CloudKit's
//  private database — the iPhone (CloudKitBridge.swift) pushes them there,
//  since WatchConnectivity can't reach visionOS directly.
//
//  Uses plain polling instead of CKSubscription/push: Simulator can't
//  reliably receive silent CloudKit pushes, so a timer-driven CKQuery is the
//  approach that actually works for local testing (and is simple enough to
//  keep for real devices too — a few seconds of latency is fine here).
//
//  Requires the same iCloud account signed in on this device and on the
//  iPhone, and a paid Apple Developer Program membership (CloudKit is not
//  available under free/personal-team signing).

import Foundation
import CloudKit

private let liveStateRecordID = CKRecord.ID(recordName: "liveState")

@MainActor
final class CloudKitWatchPuller {

    var onConnectionChange: ((Bool) -> Void)?
    var onLiveUpdate:       ((_ probability: Double, _ heartRate: Int?, _ hrv: Double?, _ battery: Float?) -> Void)?
    var onNewEvent:         ((DetectionEvent) -> Void)?

    private let container = CKContainer(identifier: "iCloud.danielramzani.EEG-Seizure-Detection")
    private lazy var database = container.privateCloudDatabase

    private var pollTask: Task<Void, Never>?
    private var seenEventIDs = Set<String>()
    private let pollInterval: TimeInterval = 3.0

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pollOnce()
                try? await Task.sleep(for: .seconds(self.pollInterval))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pollOnce() async {
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                onConnectionChange?(false)
                return
            }
        } catch {
            onConnectionChange?(false)
            return
        }

        async let live: Void  = fetchLiveState()
        async let events: Void = fetchRecentEvents()
        _ = await (live, events)
    }

    // MARK: - Live state

    private func fetchLiveState() async {
        do {
            let record = try await database.record(for: liveStateRecordID)
            onConnectionChange?(true)
            let probability = record["probability"] as? Double ?? 0
            let heartRate   = record["heartRate"] as? Int
            let hrv         = record["hrv"] as? Double
            let battery     = (record["battery"] as? Double).map { Float($0) }
            onLiveUpdate?(probability, heartRate, hrv, battery)
        } catch let error as CKError where error.code == .unknownItem {
            // No live state pushed yet — not an error, just nothing to show.
            onConnectionChange?(true)
        } catch {
            onConnectionChange?(false)
        }
    }

    // MARK: - Events

    private func fetchRecentEvents() async {
        let query = CKQuery(recordType: "SeizureEvent", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 25)
            for (recordID, result) in results {
                guard case .success(let record) = result,
                      seenEventIDs.insert(recordID.recordName).inserted,
                      let event = decode(record)
                else { continue }
                onNewEvent?(event)
            }
        } catch {
            // Non-fatal — most likely offline or not yet signed in; next poll retries.
        }
    }

    private func decode(_ record: CKRecord) -> DetectionEvent? {
        guard let payload = record["payload"] as? Data else { return nil }
        return try? JSONDecoder().decode(DetectionEvent.self, from: payload)
    }
}
