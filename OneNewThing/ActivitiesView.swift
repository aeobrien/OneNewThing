import SwiftUI
import CoreData

struct SimpleActivitiesView: View {
    @State private var filterOption: FilterOption = .all
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var assignmentManager: AssignmentManager
    @State private var hoveredActivity: Activity?
    @State private var showJournal = false
    @State private var journalActivity: Activity?
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case notCompleted = "Not Completed"
        
        var predicate: NSPredicate {
            switch self {
            case .all:
                return NSPredicate(format: "isIncluded == YES")
            case .completed:
                return NSPredicate(format: "isIncluded == YES AND isCompleted == YES")
            case .notCompleted:
                return NSPredicate(format: "isIncluded == YES AND isCompleted == NO")
            }
        }
    }
    
    @FetchRequest private var activities: FetchedResults<Activity>
    
    init() {
        let predicate = NSPredicate(format: "isIncluded == YES")
        let sortDescriptor = NSSortDescriptor(
            key: "name",
            ascending: true,
            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
        )
        _activities = FetchRequest(
            sortDescriptors: [sortDescriptor],
            predicate: predicate,
            animation: .default
        )
    }

    var filteredActivities: [Activity] {
        activities.filter { activity in
            switch filterOption {
            case .all:
                return true
            case .completed:
                return activity.isCompleted
            case .notCompleted:
                return !activity.isCompleted
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $filterOption) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            List {
                ForEach(filteredActivities, id: \.objectID) { act in
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
                    } else {
                        Divider()
                        Button(action: { makeActiveTask(activity: act) }) {
                            Label("Make active task", systemImage: "star.fill")
                                .font(.pingFangRegular(size: 15))
                        }
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
        }
        .sheet(isPresented: $showJournal) {
            NavigationStack {
                JournalFlowView(activityName: journalActivity?.name ?? "Activity")
            }
        }
    }
    
    private func toggleCompletion(activity: Activity) {
        let wasCompleted = activity.isCompleted
        activity.isCompleted.toggle()
        
        print("Activity \(activity.name ?? "") marked as \(activity.isCompleted ? "completed" : "not completed")")
        
        // Check if this is the current activity and update assignment manager
        if let currentActivity = assignmentManager.currentActivity,
           currentActivity.objectID == activity.objectID {
            if activity.isCompleted {
                assignmentManager.taskCompleted = true
            } else {
                assignmentManager.taskCompleted = false
            }
            assignmentManager.objectWillChange.send()
            
            // Reschedule notifications to reflect the new state
            NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
        }
        
        // Save the change
        try? viewContext.save()
        
        // If marking as completed, show journal
        if !wasCompleted && activity.isCompleted {
            journalActivity = activity
            showJournal = true
        }
    }
    
    private func makeActiveTask(activity: Activity) {
        // Set the new activity without changing the timer
        assignmentManager.currentActivity = activity
        UserDefaults.standard.set(activity.name, forKey: "currentActivityName")
        assignmentManager.taskCompleted = activity.isCompleted
        assignmentManager.alternativeOptions = []
        
        // Generate new alternatives for this activity
        let req: NSFetchRequest<Activity> = Activity.fetchRequest()
        req.predicate = NSPredicate(format: "isIncluded == YES AND isCompleted == NO")
        if let all = try? viewContext.fetch(req) {
            // Need to access the private method through AssignmentManager
            // We'll add a public method to handle this
            assignmentManager.setActivityMaintainingPeriod(activity, alternatives: all)
        }
        
        // Reschedule notifications to reflect the new activity
        NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
    }
}

// Keep the original view but update it to use SimpleActivitiesView
struct ActivitiesView: View {
    @State private var showCatalog = false
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isIncluded == YES"),
        animation: .default
    ) private var availableActivities: FetchedResults<Activity>
    
    var completedCount: Int {
        availableActivities.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        SimpleActivitiesView()
            .navigationTitle("Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Activities")
                            .font(.pingFangSemibold(size: 17))
                        Text("\(completedCount)/\(availableActivities.count) completed")
                            .font(.pingFangRegular(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCatalog = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 16))
                            Text("Catalog")
                                .font(.pingFangMedium(size: 16))
                        }
                        .foregroundColor(Color("AccentColor"))
                    }
                }
            }
            .sheet(isPresented: $showCatalog) {
                CatalogView()
            }
    }
}
