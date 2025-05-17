/// EditActivityView.swift
import SwiftUI
import CoreData

struct EditActivityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    var activity: Activity
    @State private var name: String
    @State private var notes: String
    @State private var selectedCategory: ExperienceCategory?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ExperienceCategory.name, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<ExperienceCategory>

    init(activity: Activity) {
        self.activity = activity
        _name = State(initialValue: activity.name ?? "")
        _notes = State(initialValue: (activity.value(forKey: "notes") as? String) ?? "")
        _selectedCategory = State(initialValue: activity.category)
    }

    var body: some View {
        Form {
            Section("Activity Name") {
                TextField("Name", text: $name)
            }
            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(height: 100)
            }
            Section("Category") {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories) { cat in
                        Text(cat.name ?? "").tag(cat as ExperienceCategory?)
                    }
                }
            }
        }
        .navigationTitle("Edit Activity")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    activity.name = name
                    activity.setValue(notes, forKey: "notes")
                    activity.category = selectedCategory
                    try? viewContext.save()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
