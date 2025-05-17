import SwiftUI
import CoreData

// Activity picker view for testing
struct ActivityPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var assignmentManager: AssignmentManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.name, ascending: true)],
        animation: .default
    )
    private var activities: FetchedResults<Activity>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(activities) { activity in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(activity.name ?? "Unnamed")
                                .fontWeight(activity.objectID == assignmentManager.currentActivity?.objectID ? .bold : .regular)
                            
                            if let category = activity.category?.name {
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if activity.objectID == assignmentManager.currentActivity?.objectID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectActivity(activity)
                    }
                }
            }
            .navigationTitle("Select Test Activity")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func selectActivity(_ activity: Activity) {
        // Set the new activity
        assignmentManager.currentActivity = activity
        UserDefaults.standard.set(activity.name, forKey: "currentActivityName")
        assignmentManager.taskCompleted = false
        assignmentManager.isOverdue = false
        assignmentManager.alternativeOffered = false
        assignmentManager.alternativeOptions = []
        
        // Reset the timer (keep it at 7 days from now)
        UserDefaults.standard.set(Date(), forKey: "lastAssignmentDate")
        
        print("✅ Manually set current activity to: \(activity.name ?? "Unnamed")")
        presentationMode.wrappedValue.dismiss()
    }
}

struct SimpleSettingsView: View {
    @EnvironmentObject var assignmentManager: AssignmentManager
    @State private var startDate: Date
    @State private var periodDays: Int = UserDefaults.standard.integer(forKey: "activityPeriodDays") > 0 ? UserDefaults.standard.integer(forKey: "activityPeriodDays") : 7
    @State private var notificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    
    init() {
        // Initialize with the current saved start date or now
        let savedDate = UserDefaults.standard.object(forKey: "lastAssignmentDate") as? Date ?? Date()
        _startDate = State(initialValue: savedDate)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Activity Period")) {
                DatePicker(
                    "Period Start Date",
                    selection: $startDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                
                Stepper(value: $periodDays, in: 1...30) {
                    Text("Activity refresh: \(periodDays) day\(periodDays == 1 ? "" : "s")")
                }
                
                Button("Update Settings") {
                    updateActivityPeriod()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
                        scheduleNotifications()
                    }
            }
            
            Section(header: Text("Debug Info")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Activity: \(assignmentManager.currentActivity?.name ?? "None")")
                    Text("Completed: \(assignmentManager.taskCompleted ? "Yes" : "No")")
                    Text("Is Overdue: \(assignmentManager.isOverdue ? "Yes" : "No")")
                }
                .font(.caption)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            print("⚙️ SimpleSettingsView appeared")
        }
    }
    
    private func updateActivityPeriod() {
        // Update UserDefaults
        UserDefaults.standard.set(startDate, forKey: "lastAssignmentDate")
        UserDefaults.standard.set(periodDays, forKey: "activityPeriodDays")
        
        // Refresh the assignmentManager with the new settings
        assignmentManager.refreshPeriod()
        
        // Update notifications
        scheduleNotifications()
        
        print("⚙️ Settings updated: period=\(periodDays) days, startDate=\(startDate)")
    }
    
    private func scheduleNotifications() {
        // Will be implemented by updating the app's notification scheduling
        NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
    }
}

// Original view now uses the simplified version
struct SettingsView: View {
    var body: some View {
        SimpleSettingsView()
    }
}
