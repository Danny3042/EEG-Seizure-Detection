//
//  WatchSessionManager.swift
//  SeizureDetection-Watch Watch App
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import WatchConnectivity

/// WCSession delegate — sends alerts to iPhone, receives config
class WatchSessionManager: NSObject, ObservableObject {
    @Published var isPhoneReachable = false
    @Published var configuration: [String: Any] = [:]
    
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
    
    // Send detection event to iPhone
    func sendDetectionEvent(_ event: DetectionEvent) {
        guard let session = session else { return }
        
        do {
            let eventData = try JSONEncoder().encode(event)
            let message = ["detectionEvent": eventData]
            
            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("Error sending detection event: \(error.localizedDescription)")
                }
            } else {
                // Use background transfer if not reachable
                try session.updateApplicationContext(["detectionEvent": eventData])
            }
            
            print("Sent detection event to iPhone: \(event.state)")
        } catch {
            print("Error encoding detection event: \(error)")
        }
    }
    
    // Send monitoring status to iPhone
    func sendMonitoringStatus(isMonitoring: Bool) {
        guard let session = session, session.isReachable else {
            print("iPhone is not reachable")
            return
        }
        
        let message = ["monitoringStatus": isMonitoring]
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending monitoring status: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("Session activation failed: \(error.localizedDescription)")
                return
            }
            
            print("Session activated with state: \(activationState.rawValue)")
            self.isPhoneReachable = session.isReachable
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            print("iPhone reachability changed: \(session.isReachable)")
        }
    }
    
    // Receive messages from iPhone
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
    
    // Receive application context updates
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.configuration = applicationContext
            print("Received configuration from iPhone")
        }
    }
    
    private func handleMessage(_ message: [String: Any]) {
        // Handle configuration updates
        if let config = message as? [String: Any] {
            configuration = config
            print("Updated configuration from iPhone")
        }
    }
}
