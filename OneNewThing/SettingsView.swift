import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var assignmentManager: AssignmentManager
    @State private var startDate: Date
    @State private var periodDays: Int = UserDefaults.standard.integer(forKey: "activityPeriodDays") > 0 ? UserDefaults.standard.integer(forKey: "activityPeriodDays") : 7
    
    // Notification settings
    @State private var notificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    @State private var notificationTimes: [Date] = loadNotificationTimes()
    @State private var notificationFrequency: Int = UserDefaults.standard.integer(forKey: "notificationFrequency") > 0 ? UserDefaults.standard.integer(forKey: "notificationFrequency") : 1
    @State private var showTimePicker = false
    @State private var selectedTimeIndex: Int?
    
    init() {
        // Initialize with the current saved start date or now
        let savedDate = UserDefaults.standard.object(forKey: "lastAssignmentDate") as? Date ?? Date()
        _startDate = State(initialValue: savedDate)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Activity Period")) {
                    DatePicker(
                        "Period Start Date",
                        selection: $startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    
                    Stepper(value: $periodDays, in: 1...30) {
                        Text("Activity refresh: \(periodDays) day\(periodDays == 1 ? "" : "s")")
                    }
                    
                    Button("Update Activity Period") {
                        updateActivityPeriod()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    
                    Text("Changing these settings will reset the countdown timer. Your current activity will remain the same.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        Picker("Notification Frequency", selection: $notificationFrequency) {
                            Text("Every day").tag(1)
                            Text("Every 2 days").tag(2)
                            Text("Every 3 days").tag(3)
                            Text("Every week").tag(7)
                        }
                        .pickerStyle(.menu)
                        
                        ForEach(0..<notificationTimes.count, id: \.self) { index in
                            HStack {
                                Text("Reminder \(index + 1)")
                                Spacer()
                                Text(formattedTime(notificationTimes[index]))
                                    .foregroundColor(.gray)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTimeIndex = index
                                showTimePicker = true
                            }
                        }
                        
                        HStack {
                            Button(action: addNotificationTime) {
                                Label("Add Reminder Time", systemImage: "plus.circle")
                            }
                            .disabled(notificationTimes.count >= 5)
                            
                            Spacer()
                            
                            if notificationTimes.count > 1 {
                                Button(action: removeLastNotificationTime) {
                                    Label("Remove", systemImage: "minus.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Text("Notifications will remind you about your current activity.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showTimePicker) {
                TimePickerView(selectedTime: selectedTimeIndex != nil ? $notificationTimes[selectedTimeIndex!] : .constant(Date())) {
                    showTimePicker = false
                    saveNotificationTimes()
                    scheduleNotifications()
                }
            }
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
    }
    
    private func addNotificationTime() {
        if notificationTimes.count < 5 {
            // Add a new time (defaults to 9 AM)
            var defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            if let lastTime = notificationTimes.last {
                // Add 3 hours to the last notification time as default
                defaultTime = Calendar.current.date(byAdding: .hour, value: 3, to: lastTime) ?? Date()
            }
            notificationTimes.append(defaultTime)
            saveNotificationTimes()
            scheduleNotifications()
        }
    }
    
    private func removeLastNotificationTime() {
        if notificationTimes.count > 1 {
            notificationTimes.removeLast()
            saveNotificationTimes()
            scheduleNotifications()
        }
    }
    
    private func saveNotificationTimes() {
        // Convert dates to strings and save
        let timeStrings = notificationTimes.map { date -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        UserDefaults.standard.set(timeStrings, forKey: "notificationTimes")
        UserDefaults.standard.set(notificationFrequency, forKey: "notificationFrequency")
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
    }
    
    private func scheduleNotifications() {
        // Will be implemented by updating the app's notification scheduling
        NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    static func loadNotificationTimes() -> [Date] {
        if let timeStrings = UserDefaults.standard.stringArray(forKey: "notificationTimes"), !timeStrings.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            return timeStrings.compactMap { timeString in
                formatter.date(from: timeString)
            }
        } else {
            // Default to 9 AM
            if let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) {
                return [defaultTime]
            }
            return [Date()]
        }
    }
}

struct TimePickerView: View {
    @Binding var selectedTime: Date
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
            }
            .navigationTitle("Select Reminder Time")
            .navigationBarItems(
                trailing: Button("Done") {
                    onDismiss()
                }
            )
        }
    }
}
