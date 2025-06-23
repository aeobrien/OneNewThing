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
            ZStack {
                // Background
                Color.primary.opacity(0.03)
                    .edgesIgnoringSafeArea(.all)
                
                List {
                ForEach(categories) { category in
                    Section(header: 
                        Text(category.name ?? "")
                            .font(.pingFangSemibold(size: 18))
                            .foregroundColor(.primary)
                            .textCase(nil)
                    ) {
                        ForEach(category.activitiesArray, id: \.objectID) { activity in
                            HStack(spacing: 16) {
                                Toggle(isOn: Binding(
                                    get: { activity.isIncluded },
                                    set: { newValue in
                                        activity.isIncluded = newValue
                                        try? viewContext.save()
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(activity.name ?? "")
                                            .font(.pingFangMedium(size: 17))
                                            .strikethrough(activity.isCompleted, color: .red)
                                            .foregroundColor(activity.isCompleted ? .gray : .primary)
                                        
                                        if activity.isCompleted {
                                            Text("Completed")
                                                .font(.pingFangLight(size: 13))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                                
                                Spacer()
                                
                                if editMode == .active {
                                    Button(action: {
                                        selectedActivityForEdit = activity
                                    }) {
                                        Image(systemName: "pencil.circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(Color("AccentColor"))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Activity Catalog")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .font(.pingFangMedium(size: 16))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.pingFangMedium(size: 16))
                            .foregroundColor(Color("AccentColor"))
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
            .onAppear {
                // Apply custom list style
                UITableView.appearance().backgroundColor = UIColor.clear
                UITableView.appearance().separatorStyle = .singleLine
                UITableView.appearance().separatorColor = UIColor.separator.withAlphaComponent(0.3)
            }
        }
    }
}

