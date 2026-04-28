//
//  WatchSessionManager.swift
//  SeizureDetection-Watch Watch App
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import WatchConnectivity
import Combine

/// WCSession delegate — sends alerts to iPhone, receives config.
/// Class is NOT @MainActor so WCSessionDelegate conformance has no isolation conflict;
/// UI-facing property mutations are dispatched to the main queue explicitly.
class WatchSessionManager: NSObject, ObservableObject {

    @Published var isPhoneReachable = false
    @Published var configuration: [String: Any] = [:]

    private var session: WCSession?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let wc = WCSession.default
        wc.delegate = self
        wc.activate()
        session = wc
    }

    func activateSession() {
        session?.activate()
    }

    // MARK: - Outbound

    func sendDetectionEvent(_ event: DetectionEvent) {
        guard let session else { return }
        do {
            let data = try JSONEncoder().encode(event)
            let msg: [String: Any] = ["detectionEvent": data]
            if session.isReachable {
                session.sendMessage(msg, replyHandler: nil) { error in
                    print("WCSession send error: \(error.localizedDescription)")
                }
            } else {
                try session.updateApplicationContext(msg)
            }
        } catch {
            print("WCSession encode error: \(error)")
        }
    }

    func sendMonitoringStatus(isMonitoring: Bool) {
        guard let session, session.isReachable else { return }
        session.sendMessage(["monitoringStatus": isMonitoring], replyHandler: nil) { error in
            print("WCSession monitoring status error: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.handleMessage(message) }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleMessage(message)
            replyHandler(["status": "received"])
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.configuration = applicationContext
        }
    }

    // iOS requires these two; watchOS does not.
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif

    // MARK: Private

    private func handleMessage(_ message: [String: Any]) {
        configuration = message
    }
}
