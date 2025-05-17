/// CatalogView.swift
import SwiftUI
import CoreData

struct CatalogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ExperienceCategory.name, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<ExperienceCategory>

    @State private var editMode: EditMode = .inactive
    @State private var showingAdd = false
    @State private var selectedActivityForEdit: Activity?

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Section(header: Text(category.name ?? "")) {
                        ForEach(category.activitiesArray, id: \.objectID) { activity in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { activity.isIncluded },
                                    set: { newValue in
                                        activity.isIncluded = newValue
                                        try? viewContext.save()
                                    }
                                )) {
                                    Text(activity.name ?? "")
                                }
                                Spacer()
                                if editMode == .active {
                                    Button(action: {
                                        selectedActivityForEdit = activity
                                    }) {
                                        Image(systemName: "pencil")
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let items = category.activitiesArray
                            indexSet.forEach { idx in
                                viewContext.delete(items[idx])
                            }
                            try? viewContext.save()
                        }
                    }
                }
            }
            .navigationTitle("Catalog")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    AddNewActivityView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(item: $selectedActivityForEdit) { activity in
                EditActivityView(activity: activity)
            }
        }
    }
}

