//
//  JournalManager.swift
//  EEGSeizureDetection
//
//  Free-text seizure journal — symptoms, triggers, how the user felt.
//  Persisted locally in UserDefaults as JSON.

import Foundation
import Combine
import SwiftUI

struct JournalEntry: Identifiable, Codable {
    let id:   UUID
    var date: Date
    var text: String
    var mood: Mood

    enum Mood: String, Codable, CaseIterable {
        case good  = "Good"
        case okay  = "Okay"
        case rough = "Rough"

        var emoji: String {
            switch self {
            case .good:  return "🙂"
            case .okay:  return "😐"
            case .rough: return "😣"
            }
        }
    }

    init(text: String, mood: Mood, date: Date = Date()) {
        self.id   = UUID()
        self.date = date
        self.text = text
        self.mood = mood
    }
}

class JournalManager: ObservableObject {
    static let shared = JournalManager()

    @Published var entries: [JournalEntry] = [] {
        didSet { save() }
    }

    private let storageKey = "journal_entries"

    private init() { load() }

    func add(text: String, mood: JournalEntry.Mood) {
        entries.insert(JournalEntry(text: text, mood: mood), at: 0)
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
