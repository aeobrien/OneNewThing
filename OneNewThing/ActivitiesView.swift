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
    @State private var showJournal = false
    @State private var completedActivityName: String = ""

    var body: some View {
        List {
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
                .padding(.vertical, 8)
                .background(
                    act.objectID == assignmentManager.currentActivity?.objectID ?
                    Color("AccentColor").opacity(0.05) : Color.clear
                )
                .overlay(
                    act.objectID == assignmentManager.currentActivity?.objectID ?
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color("AccentColor").opacity(0.3), lineWidth: 1)
                        .padding(.horizontal, -8)
                    : nil
                )
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
            }
        }
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            // Apply custom list style
            UITableView.appearance().backgroundColor = UIColor.clear
            UITableView.appearance().separatorStyle = .none
            
            print("📋 SimpleActivitiesView appeared with \(activities.count) activities")
        }
        .sheet(isPresented: $showJournal) {
            NavigationView {
                JournalFlowView(activityName: completedActivityName)
            }
        }
    }
    
    private func toggleCompletion(activity: Activity) {
        viewContext.perform {
            let wasCompleted = activity.isCompleted
            activity.isCompleted.toggle()
            print("Activity \(activity.name ?? "") marked as \(activity.isCompleted ? "completed" : "not completed")")
            
            // Check if this is the current activity and update assignment manager
            if let currentActivity = assignmentManager.currentActivity, 
               currentActivity.objectID == activity.objectID {
                // Update assignment manager state to match
                DispatchQueue.main.async {
                    if activity.isCompleted {
                        assignmentManager.taskCompleted = true
                        // Trigger journal for current activity
                        self.completedActivityName = activity.name ?? "Activity"
                        self.showJournal = true
                    } else {
                        assignmentManager.taskCompleted = false
                    }
                    // Ensure UI updates
                    assignmentManager.objectWillChange.send()
                    print("Updated assignment manager state for current activity")
                }
            } else if !wasCompleted && activity.isCompleted {
                // Non-current activity marked as completed - still show journal
                DispatchQueue.main.async {
                    self.completedActivityName = activity.name ?? "Activity"
                    self.showJournal = true
                }
            }
            
            try? viewContext.save()
        }
    }
}

// Keep the original view but update it to use SimpleActivitiesView
struct ActivitiesView: View {
    @State private var showCatalog = false
    
    var body: some View {
        NavigationStack {
            SimpleActivitiesView()
                .navigationTitle("Activities")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCatalog = true
                        } label: {
                            Label("Catalog", systemImage: "folder")
                                .font(.pingFangMedium(size: 16))
                        }
                    }
                }
                .sheet(isPresented: $showCatalog) {
                    CatalogView()
                }
        }
    }
}
