//
//  PhoneSessionManager.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import WatchConnectivity
import Combine

/// WCSession delegate — receives alerts from Watch, sends to visionOS
class PhoneSessionManager: NSObject, ObservableObject {
    @Published var detectionEvents:      [DetectionEvent] = [] {
        didSet { saveEvents() }
    }
    @Published var isWatchReachable      = false
    #if os(iOS)
    // "Connected" should mean "paired + app installed", not momentary live
    // reachability — the Watch screen turning off or the app backgrounding
    // flips isReachable to false constantly even though it's still there.
    @Published var isWatchPaired         = false
    @Published var isWatchAppInstalled   = false
    #endif
    // Live streaming from Watch demo
    @Published var liveProbability:      Double  = 0
    @Published var liveHeartRate:        Int?    = nil
    @Published var liveHRV:              Double? = nil
    @Published var watchBatteryLevel:    Float?  = nil
    @Published var lastCheckedAt:        Date    = Date()
    // Emergency alert trigger
    @Published var showEmergencyAlert    = false
    @Published var pendingEmergencyEvent: DetectionEvent? = nil

    var appModel: AppModel?

    private var session: WCSession?
    private let eventsStorageKey = "detection_events"
    private let maxStoredEvents  = 300
    private var isLoadingEvents  = false

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }

        loadEvents()
    }

    func activateSession() {
        session?.activate()
    }

    func clearEvents() {
        detectionEvents.removeAll()
    }

    // MARK: - Persistence

    private func saveEvents() {
        guard !isLoadingEvents else { return }
        let capped = Array(detectionEvents.prefix(maxStoredEvents))
        guard let data = try? JSONEncoder().encode(capped) else { return }
        UserDefaults.standard.set(data, forKey: eventsStorageKey)
    }

    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: eventsStorageKey),
              let decoded = try? JSONDecoder().decode([DetectionEvent].self, from: data)
        else { return }
        isLoadingEvents = true
        detectionEvents = decoded
        isLoadingEvents = false
    }
    
    // Send configuration to Watch
    func sendConfiguration(_ config: [String: Any]) {
        guard let session = session, session.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        session.sendMessage(config, replyHandler: nil) { error in
            print("Error sending configuration: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("Session activation failed: \(error.localizedDescription)")
                return
            }
            
            print("Session activated with state: \(activationState.rawValue)")
            self.isWatchReachable = session.isReachable
            #if os(iOS)
            self.isWatchPaired       = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("Session deactivated")
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired       = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    #endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")
        }
    }
    
    // Receive messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleMessage(message)
            replyHandler(["status": "received"])
        }
    }
    
    private func handleMessage(_ message: [String: Any]) {
        // Live streaming data from Watch demo
        if let live = message["live"] as? [String: Any],
           let p = live["p"] as? Double {
            liveProbability = p
            liveHeartRate   = live["hr"] as? Int
            liveHRV         = live["hrv"] as? Double
            if let battery = live["battery"] as? Float { watchBatteryLevel = battery }
            lastCheckedAt   = Date()
        }

        // Threshold crossing events
        if let eventData = message["detectionEvent"] as? Data {
            do {
                let event = try JSONDecoder().decode(DetectionEvent.self, from: eventData)
                detectionEvents.insert(event, at: 0)
                appModel?.detectionEvents.insert(event, at: 0)
                forwardToVisionOS(event: event)
                if event.type == .emergency {
                    pendingEmergencyEvent = event
                    showEmergencyAlert    = true
                }
                print("Watch event: \(event.type) \(event.probabilityPercent)")
            } catch {
                print("Error decoding detection event: \(error)")
            }
        }
    }
    
    private func forwardToVisionOS(event: DetectionEvent) {
        // Implement visionOS forwarding logic here
        // This could use Group Activities, Multipeer Connectivity, or other methods
        print("Forwarding event to visionOS: \(event.id)")
    }
}
