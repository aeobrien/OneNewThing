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

    var body: some View {
        List {
            ForEach(activities, id: \.objectID) { act in
                HStack {
                    VStack(alignment: .leading) {
                        Text(act.name ?? "")
                            .strikethrough(act.isCompleted, color: .red)
                            .foregroundColor(act.isCompleted ? .gray : .primary)
                        
                        if let category = act.category?.name {
                            Text(category)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if act.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .contentShape(Rectangle())
                .contextMenu {
                    if act.isCompleted {
                        Button(action: { toggleCompletion(activity: act) }) {
                            Label("Mark as not completed", systemImage: "arrow.uturn.left")
                        }
                    } else {
                        Button(action: { toggleCompletion(activity: act) }) {
                            Label("Mark as completed", systemImage: "checkmark.circle")
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            print("📋 SimpleActivitiesView appeared with \(activities.count) activities")
        }
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
