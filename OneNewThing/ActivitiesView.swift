import SwiftUI
import CoreData

struct SimpleActivitiesView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.name, ascending: true)],
        predicate: NSPredicate(format: "isIncluded == YES"),
        animation: .default
    )
    private var activities: FetchedResults<Activity>

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var assignmentManager: AssignmentManager
    @State private var hoveredActivity: Activity?
    @State private var showingCatalog = false
    @State private var selectedActivityForDetails: Activity?

    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar to eliminate spacing issues
            HStack {
                Text("Activities")
                    .font(.pingFangSemibold(size: 17))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    showingCatalog = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.systemGray4)),
                alignment: .bottom
            )
            
            // Custom scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(activities, id: \.objectID) { act in
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(act.name ?? "")
                                    .font(.pingFangMedium(size: 17))
                                    .strikethrough(act.isCompleted, color: .red)
                                    .foregroundColor(act.isCompleted ? .gray : .primary)
                                
                                if let category = act.category?.name {
                                    Text(category)
                                        .font(.pingFangLight(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if act.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color("AccentColor"))
                                    .font(.system(size: 22))
                                    .symbolRenderingMode(.hierarchical)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(
                            act.objectID == assignmentManager.currentActivity?.objectID ?
                            Color("AccentColor").opacity(0.05) : Color(.systemBackground)
                        )
                        .overlay(
                            act.objectID == assignmentManager.currentActivity?.objectID ?
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color("AccentColor").opacity(0.3), lineWidth: 1)
                            : nil
                        )
                        .onTapGesture {
                            selectedActivityForDetails = act
                        }
                        .contextMenu {
                            if act.isCompleted {
                                Button(action: { toggleCompletion(activity: act) }) {
                                    Label("Mark as not completed", systemImage: "arrow.uturn.left")
                                        .font(.pingFangRegular(size: 15))
                                }
                            } else {
                                Button(action: { toggleCompletion(activity: act) }) {
                                    Label("Mark as completed", systemImage: "checkmark.circle")
                                        .font(.pingFangRegular(size: 15))
                                }
                            }
                            
                            if act.objectID == assignmentManager.currentActivity?.objectID {
                                Divider()
                                Text("Current Activity")
                                    .font(.pingFangMedium(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                            .padding(.leading)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCatalog) {
            CatalogView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $selectedActivityForDetails) { activity in
            NavigationView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(activity.name ?? "Activity")
                        .font(.title)
                        .padding(.horizontal)
                    
                    if let category = activity.category?.name {
                        Text("Category: \(category)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    if let notes = activity.notes, !notes.isEmpty {
                        Text("Notes:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text(notes)
                            .padding(.horizontal)
                    } else {
                        Text("No notes available")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
                .navigationTitle("Activity Details")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") {
                    selectedActivityForDetails = nil
                })
            }
        }
        .accentColor(Color("AccentColor"))
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private func toggleCompletion(activity: Activity) {
        viewContext.perform {
            activity.isCompleted.toggle()
            print("Activity \(activity.name ?? "") marked as \(activity.isCompleted ? "completed" : "not completed")")
            
            // Check if this is the current activity and update assignment manager
            if let currentActivity = assignmentManager.currentActivity, 
               currentActivity.objectID == activity.objectID {
                // Update assignment manager state to match
                DispatchQueue.main.async {
                    if activity.isCompleted {
                        assignmentManager.taskCompleted = true
                    } else {
                        assignmentManager.taskCompleted = false
                    }
                    // Ensure UI updates
                    assignmentManager.objectWillChange.send()
                    print("Updated assignment manager state for current activity")
                }
            }
            
            try? viewContext.save()
        }
    }
}

// Keep the original view but update it to use SimpleActivitiesView
struct ActivitiesView: View {
    var body: some View {
        SimpleActivitiesView()
    }
}

