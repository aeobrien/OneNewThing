/// EditJournalView.swift
import SwiftUI
import CoreData

struct EditJournalView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    var entry: JournalEntry
    @State private var text: String

    init(entry: JournalEntry) {
        self.entry = entry
        _text = State(initialValue: entry.text ?? "")
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
            Spacer()
        }
        .navigationTitle(entry.title ?? "Journal")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    entry.text = text
                    try? viewContext.save()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}
