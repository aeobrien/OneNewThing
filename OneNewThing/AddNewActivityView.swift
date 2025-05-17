/// AddNewActivityView.swift
import SwiftUI
import CoreData

struct AddNewActivityView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var notes = ""
    @State private var selectedCategory: ExperienceCategory?
    @State private var newCategoryName = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ExperienceCategory.name, ascending: true)])
    private var categories: FetchedResults<ExperienceCategory>

    var body: some View {
        Form {
            Section("Activity Name") {
                TextField("Enter name", text: $name)
            }
            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(height: 100)
            }
            Section("Category") {
                Picker("Select category", selection: $selectedCategory) {
                    ForEach(categories) { cat in
                        Text(cat.name ?? "").tag(cat as ExperienceCategory?)
                    }
                }
                HStack {
                    TextField("New category", text: $newCategoryName)
                    Button("Add") {
                        let cat = ExperienceCategory(context: viewContext)
                        cat.name = newCategoryName
                        try? viewContext.save()
                        selectedCategory = cat
                        newCategoryName = ""
                    }
                }
            }
        }
        .navigationTitle("Add Activity")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard !name.isEmpty, let cat = selectedCategory else { return }
                    let act = Activity(context: viewContext)
                    act.name = name
                    act.notes = notes
                    act.isIncluded = true
                    act.isCompleted = false
                    act.category = cat
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
