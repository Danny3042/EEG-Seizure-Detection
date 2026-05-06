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
    @Published var detectionEvents: [DetectionEvent] = []
    @Published var isWatchReachable = false

    /// Set by the app entry point so incoming Watch events are also
    /// forwarded into the shared AppModel that DashboardView reads.
    var appModel: AppModel?

    private var session: WCSession?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }
    }
    
    func activateSession() {
        session?.activate()
    }
    
    func clearEvents() {
        detectionEvents.removeAll()
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
        if let eventData = message["detectionEvent"] as? Data {
            do {
                let event = try JSONDecoder().decode(DetectionEvent.self, from: eventData)
                // EventLogView
                detectionEvents.insert(event, at: 0)
                // DashboardView event log
                appModel?.detectionEvents.insert(event, at: 0)
                forwardToVisionOS(event: event)
                print("Watch event received: \(event.type) \(event.probabilityPercent)")
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
