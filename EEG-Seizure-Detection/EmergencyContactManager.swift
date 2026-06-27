//
//  EmergencyContactManager.swift
//  EEGSeizureDetection
//
//  Persists an emergency contact in UserDefaults and builds the SMS URL
//  used to pre-fill a message when a high-risk event fires.

import SwiftUI
import Combine

class EmergencyContactManager: ObservableObject {

    static let shared = EmergencyContactManager()

    @Published var contactName: String {
        didSet { UserDefaults.standard.set(contactName,  forKey: "ec_name")  }
    }
    @Published var contactPhone: String {
        didSet { UserDefaults.standard.set(contactPhone, forKey: "ec_phone") }
    }

    private init() {
        contactName  = UserDefaults.standard.string(forKey: "ec_name")  ?? ""
        contactPhone = UserDefaults.standard.string(forKey: "ec_phone") ?? ""
    }

    var isConfigured: Bool { !contactName.isEmpty && !contactPhone.isEmpty }

    /// Returns a pre-filled sms: URL that opens Messages with the alert body.
    func smsURL(probability: Double) -> URL? {
        let pct  = Int(probability * 100)
        let body = "⚠️ SEIZURE ALERT: Possible seizure detected (pIctal \(pct)%). Please check on me immediately."
        guard let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:\(contactPhone)&body=\(encoded)")
        else { return nil }
        return url
    }
}
