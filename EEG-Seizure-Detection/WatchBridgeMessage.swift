//
//  WatchBridgeMessage.swift
//  Shared — compiled into EEG-Seizure-Detection (iOS) and EEG-Dashboard-visionOS.
//
//  Wire format for the Simulator-friendly localhost bridge that relays Watch
//  data from the iPhone to visionOS. WatchConnectivity can't reach visionOS
//  directly, and Bonjour/Multipeer discovery is unreliable in Simulator
//  (Bluetooth isn't available there at all, and Bonjour peer discovery
//  between two Simulator processes is known to be flaky), so this uses a
//  plain newline-delimited JSON TCP stream on 127.0.0.1 — the iOS and
//  visionOS Simulators are ordinary processes on the same Mac and share its
//  loopback interface, so this connects deterministically with no network
//  permissions, no iCloud account, and no paid developer team required.
//
//  This does NOT work between two physical devices (each has its own,
//  separate loopback) — CloudKitBridge/CloudKitWatchPuller cover that case.

import Foundation

let watchBridgePort: UInt16 = 51820

struct BridgeMessage: Codable {
    enum Kind: String, Codable { case live, event }

    let kind:        Kind
    var probability: Double?         = nil
    var heartRate:   Int?            = nil
    var hrv:         Double?         = nil
    var battery:     Float?          = nil
    var event:       DetectionEvent? = nil

    static func live(probability: Double, heartRate: Int?, hrv: Double?, battery: Float?) -> BridgeMessage {
        BridgeMessage(kind: .live, probability: probability, heartRate: heartRate, hrv: hrv, battery: battery)
    }

    static func event(_ event: DetectionEvent) -> BridgeMessage {
        BridgeMessage(kind: .event, event: event)
    }
}
