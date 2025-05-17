/// EditActivityView.swift
import SwiftUI
import CoreData

struct EditActivityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.dismiss) private var dismiss

    var activity: Activity
    @State private var name: String
    @State private var notes: String
    @State private var selectedCategory: ExperienceCategory?
    @State private var showingSaveAlert = false

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
                    .font(.pingFangRegular(size: 16))
            }
            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .font(.pingFangRegular(size: 16))
            }
            Section("Category") {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories) { cat in
                        Text(cat.name ?? "").tag(cat as ExperienceCategory?)
                    }
                }
                .font(.pingFangRegular(size: 16))
            }
            
            Section {
                Button("Save Changes") {
                    saveActivity()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("AccentColor"))
                )
                .foregroundColor(.white)
                .font(.pingFangMedium(size: 16))
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .navigationTitle("Edit Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveActivity()
                }
                .font(.pingFangMedium(size: 16))
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.pingFangRegular(size: 16))
            }
        }
        .alert(isPresented: $showingSaveAlert) {
            Alert(
                title: Text("Cannot Save"),
                message: Text("Activity name cannot be empty."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func saveActivity() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showingSaveAlert = true
            return
        }
        
        activity.name = name
        activity.setValue(notes, forKey: "notes")
        activity.category = selectedCategory
        try? viewContext.save()
        dismiss()
    }
}
