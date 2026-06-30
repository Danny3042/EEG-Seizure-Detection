//
//  JournalView.swift
//  EEGSeizureDetection
//

import SwiftUI

struct JournalView: View {
    @ObservedObject private var journal = JournalManager.shared
    @State private var showNewEntry = false

    var body: some View {
        NavigationStack {
            Group {
                if journal.entries.isEmpty {
                    ContentUnavailableView(
                        "No Journal Entries",
                        systemImage: "doc.text",
                        description: Text("Log how you're feeling, symptoms, or possible triggers")
                    )
                } else {
                    List {
                        ForEach(journal.entries) { entry in
                            JournalRow(entry: entry)
                        }
                        .onDelete(perform: journal.delete)
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNewEntry = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showNewEntry) {
                NewJournalEntryView()
            }
        }
    }
}

private struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.mood.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(.body)
                    .lineLimit(3)
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NewJournalEntryView: View {
    @ObservedObject private var journal = JournalManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var mood: JournalEntry.Mood = .okay

    var body: some View {
        NavigationStack {
            Form {
                Section("How are you feeling?") {
                    Picker("Mood", selection: $mood) {
                        ForEach(JournalEntry.Mood.allCases, id: \.self) { m in
                            Text("\(m.emoji) \(m.rawValue)").tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        journal.add(text: text, mood: mood)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    JournalView()
}
