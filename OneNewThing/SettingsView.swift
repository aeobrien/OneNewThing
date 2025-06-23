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
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
    @State private var showAPIKey: Bool = false
    
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
            Section(header: Text("Activity Period").font(.pingFangMedium(size: 14))) {
                DatePicker(
                    "Period Start Date",
                    selection: $startDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .font(.pingFangRegular(size: 16))
                
                Stepper(value: $periodDays, in: 1...30) {
                    Text("Activity refresh: \(periodDays) day\(periodDays == 1 ? "" : "s")")
                        .font(.pingFangRegular(size: 16))
                }
                
                Button("Update Settings") {
                    updateActivityPeriod()
                }
                .font(.pingFangMedium(size: 16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("AccentColor"))
                )
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .buttonStyle(ScaleButtonStyle())
            }
            
            Section(header: Text("Notifications").font(.pingFangMedium(size: 14))) {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                    .font(.pingFangRegular(size: 16))
                    .onChange(of: notificationsEnabled) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
                        scheduleNotifications()
                    }
                
                if notificationsEnabled {
                    // Notification frequency (every X days)
                    Stepper(value: $notificationFrequency, in: 1...7) {
                        Text("Every \(notificationFrequency) day\(notificationFrequency == 1 ? "" : "s")")
                            .font(.pingFangRegular(size: 16))
                    }
                    .onChange(of: notificationFrequency) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "notificationFrequency")
                        scheduleNotifications()
                    }
                    
                    // Section title for notification times
                    HStack {
                        Text("Notification Times")
                            .font(.pingFangMedium(size: 16))
                        Spacer()
                        Button(action: {
                            showingAddTime = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color("AccentColor"))
                                .font(.system(size: 18))
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    
                    // List of current notification times
                    if notificationTimes.isEmpty {
                        Text("No notifications scheduled")
                            .font(.pingFangLight(size: 15))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .center)
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
                                .font(.pingFangRegular(size: 16))
                                
                                if notificationTimes.count > 1 {
                                    Button(action: {
                                        self.notificationTimes.remove(at: index)
                                        self.saveNotificationTimes()
                                        self.scheduleNotifications()
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 18))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Notification summary
                    if !notificationTimes.isEmpty {
                        Text("Notifications will be sent \(notificationTimes.count > 1 ? "at \(notificationTimes.count) different times" : "once") each day, every \(notificationFrequency) day\(notificationFrequency > 1 ? "s" : "").")
                            .font(.pingFangLight(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }
                }
            }
            
            Section(header: Text("API Configuration").font(.pingFangMedium(size: 14))) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("OpenAI API Key")
                        .font(.pingFangRegular(size: 14))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        if showAPIKey {
                            TextField("Enter API Key", text: $apiKey)
                                .font(.pingFangRegular(size: 16))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Enter API Key", text: $apiKey)
                                .font(.pingFangRegular(size: 16))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        Button(action: {
                            showAPIKey.toggle()
                        }) {
                            Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18))
                        }
                    }
                    
                    Text("Required for voice transcription in journal entries")
                        .font(.pingFangLight(size: 13))
                        .foregroundColor(.secondary)
                    
                    Button("Save API Key") {
                        UserDefaults.standard.set(apiKey, forKey: "openAIAPIKey")
                        // Clear keyboard
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(.pingFangMedium(size: 16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(apiKey.isEmpty ? Color.gray.opacity(0.3) : Color("AccentColor"))
                    )
                    .foregroundColor(.white)
                    .disabled(apiKey.isEmpty)
                    .padding(.top, 8)
                }
                .padding(.vertical, 6)
            }
            
            Section(header: Text("Debug Info").font(.pingFangMedium(size: 14))) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Current Activity:")
                            .font(.pingFangRegular(size: 14))
                            .foregroundColor(.secondary)
                        Text(assignmentManager.currentActivity?.name ?? "None")
                            .font(.pingFangMedium(size: 14))
                    }
                    
                    HStack {
                        Text("Completed:")
                            .font(.pingFangRegular(size: 14))
                            .foregroundColor(.secondary)
                        Text(assignmentManager.taskCompleted ? "Yes" : "No")
                            .font(.pingFangMedium(size: 14))
                            .foregroundColor(assignmentManager.taskCompleted ? .green : .primary)
                    }
                    
                    HStack {
                        Text("Is Overdue:")
                            .font(.pingFangRegular(size: 14))
                            .foregroundColor(.secondary)
                        Text(assignmentManager.isOverdue ? "Yes" : "No")
                            .font(.pingFangMedium(size: 14))
                            .foregroundColor(assignmentManager.isOverdue ? .red : .primary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Settings")
        .accentColor(Color("AccentColor"))
        .sheet(isPresented: $showingAddTime) {
            NavigationView {
                VStack {
                    DatePicker(
                        "Select Time",
                        selection: $newNotificationTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                    .frame(maxWidth: .infinity)
                    
                    Text("Choose when you'd like to receive notifications")
                        .font(.pingFangLight(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .navigationTitle("Add Notification")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingAddTime = false
                    }
                    .font(.pingFangRegular(size: 16)),
                    trailing: Button("Add") {
                        addNotificationTime()
                        showingAddTime = false
                    }
                    .font(.pingFangMedium(size: 16))
                    .foregroundColor(Color("AccentColor"))
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
