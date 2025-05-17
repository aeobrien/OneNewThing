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
    
    // Notification settings
    @State private var notificationFrequency: Int = UserDefaults.standard.integer(forKey: "notificationFrequency") > 0 ? UserDefaults.standard.integer(forKey: "notificationFrequency") : 1
    
    // Store array of notification times
    @State private var notificationTimes: [Date] = {
        if let savedTimes = UserDefaults.standard.array(forKey: "notificationTimes") as? [Data] {
            return savedTimes.compactMap { data -> Date? in
                if let nsDate = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDate.self, from: data) {
                    return nsDate as Date
                }
                return nil
            }
        } else {
            // Default to 9:00 AM
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            return [Calendar.current.date(from: components) ?? Date()]
        }
    }()
    
    // Show add notification time sheet
    @State private var showingAddTime = false
    @State private var newNotificationTime = Date()
    
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
                
                if notificationsEnabled {
                    // Notification frequency (every X days)
                    Stepper(value: $notificationFrequency, in: 1...7) {
                        Text("Every \(notificationFrequency) day\(notificationFrequency == 1 ? "" : "s")")
                    }
                    .onChange(of: notificationFrequency) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "notificationFrequency")
                        scheduleNotifications()
                    }
                    
                    // Section title for notification times
                    HStack {
                        Text("Notification Times")
                        Spacer()
                        Button(action: {
                            showingAddTime = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                    .padding(.top, 8)
                    
                    // List of current notification times
                    if notificationTimes.isEmpty {
                        Text("No notifications scheduled")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(0..<notificationTimes.count, id: \.self) { index in
                            HStack {
                                DatePicker(
                                    "Time \(index + 1)",
                                    selection: Binding(
                                        get: { self.notificationTimes[index] },
                                        set: { 
                                            self.notificationTimes[index] = $0
                                            self.saveNotificationTimes()
                                            self.scheduleNotifications()
                                        }
                                    ),
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                
                                if notificationTimes.count > 1 {
                                    Button(action: {
                                        self.notificationTimes.remove(at: index)
                                        self.saveNotificationTimes()
                                        self.scheduleNotifications()
                                    }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Notification summary
                    if !notificationTimes.isEmpty {
                        Text("Notifications will be sent \(notificationTimes.count > 1 ? "at \(notificationTimes.count) different times" : "once") each day, every \(notificationFrequency) day\(notificationFrequency > 1 ? "s" : "").")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
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
        .sheet(isPresented: $showingAddTime) {
            NavigationView {
                Form {
                    DatePicker(
                        "New Notification Time",
                        selection: $newNotificationTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .padding()
                }
                .navigationTitle("Add Notification")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingAddTime = false
                    },
                    trailing: Button("Add") {
                        addNotificationTime()
                        showingAddTime = false
                    }
                )
            }
        }
        .onAppear {
            print("⚙️ SimpleSettingsView appeared with \(notificationTimes.count) notification times")
        }
    }
    
    // Add a new notification time
    private func addNotificationTime() {
        notificationTimes.append(newNotificationTime)
        // Sort times chronologically
        notificationTimes.sort()
        saveNotificationTimes()
        scheduleNotifications()
    }
    
    // Save notification times to UserDefaults
    private func saveNotificationTimes() {
        let encodedTimes = notificationTimes.compactMap { time -> Data? in
            try? NSKeyedArchiver.archivedData(withRootObject: time as NSDate, requiringSecureCoding: false)
        }
        UserDefaults.standard.set(encodedTimes, forKey: "notificationTimes")
    }
    
    // Format time to display in a user-friendly way
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
        // Save all notification settings
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(notificationFrequency, forKey: "notificationFrequency")
        
        // Post notification to request rescheduling
        NotificationCenter.default.post(
            name: Notification.Name("RescheduleNotifications"), 
            object: nil,
            userInfo: [
                "enabled": notificationsEnabled,
                "frequency": notificationFrequency,
                "times": notificationTimes
            ]
        )
        
        print("⚙️ Notification settings updated: enabled=\(notificationsEnabled), frequency=\(notificationFrequency), count=\(notificationTimes.count)")
    }
}

// Original view now uses the simplified version
struct SettingsView: View {
    var body: some View {
        SimpleSettingsView()
    }
}
