/// EditJournalView.swift
import SwiftUI
import CoreData

struct EditJournalView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var entry: JournalEntry
    @State private var text: String
    @State private var title: String

    init(entry: JournalEntry) {
        self.entry = entry
        _text = State(initialValue: entry.text ?? "")
        _title = State(initialValue: entry.title ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Editable activity name and date
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity Name:")
                            .font(.pingFangLight(size: 14))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter activity name", text: $title)
                            .font(.pingFangSemibold(size: 24))
                            .foregroundColor(.primary)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Text(entry.date ?? Date(), style: .date)
                        .font(.pingFangLight(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Journal Entry:")
                        .font(.pingFangLight(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TextEditor(text: $text)
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Edit Journal")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewContext.perform {
                        entry.text = text
                        entry.title = title
                        do {
                            try viewContext.save()
                            DispatchQueue.main.async {
                                presentationMode.wrappedValue.dismiss()
                            }
                        } catch {
                            print("Error saving journal entry: \(error)")
                        }
                    }
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}