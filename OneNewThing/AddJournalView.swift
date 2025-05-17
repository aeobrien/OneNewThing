/// AddJournalView.swift
import SwiftUI

struct AddJournalView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    var activity: Activity?
    @State private var text = ""

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $text)
                    .padding()
                Spacer()
            }
            .navigationTitle(activity?.name ?? "Journal Entry")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = JournalEntry(context: viewContext)
                        entry.date = Date()
                        entry.title = activity?.name
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
}
