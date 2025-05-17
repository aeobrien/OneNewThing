// NewExperiencesApp.swift
import SwiftUI
import UserNotifications

// Class to handle notifications
class NotificationManager {
    static let shared = NotificationManager()
    private var observerToken: Any?
    
    // Store a weak reference to the shared AssignmentManager
    weak var assignmentManager: AssignmentManager?
    
    init() {
        // Set up the observer in the NotificationManager
        observerToken = NotificationCenter.default.addObserver(
            forName: Notification.Name("RescheduleNotifications"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let manager = self.assignmentManager else { return }
            self.scheduleAllNotifications(using: manager)
        }
    }
    
    deinit {
        // Clean up the observer when the manager is deallocated
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func scheduleAllNotifications(using mgr: AssignmentManager) {
        // Remove all existing notifications
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        // Check if notifications are enabled
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        guard notificationsEnabled else { 
            print("📱 Notifications disabled, not scheduling any")
            return 
        }
        
        // Get notification frequency (default to daily)
        let frequency = UserDefaults.standard.integer(forKey: "notificationFrequency")
        let dayInterval = frequency > 0 ? frequency : 1
        
        // Get notification times
        var notificationTimes: [Date] = []
        
        // Try to load saved notification times
        if let savedTimes = UserDefaults.standard.array(forKey: "notificationTimes") as? [Data] {
            notificationTimes = savedTimes.compactMap { data -> Date? in
                if let nsDate = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDate.self, from: data) {
                    return nsDate as Date
                }
                return nil
            }
        }
        
        // If no times are found, use a default 9:00 AM
        if notificationTimes.isEmpty {
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            if let defaultTime = Calendar.current.date(from: components) {
                notificationTimes = [defaultTime]
                print("📱 No notification times found, using default (09:00)")
            }
        }
        
        // Sort times chronologically
        notificationTimes.sort()
        
        // Schedule each notification at its specific time
        for (index, time) in notificationTimes.enumerated() {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: time)
            let minute = calendar.component(.minute, from: time)
            
            let timeString = String(format: "%02d:%02d", hour, minute)
            print("📱 Scheduling notification \(index + 1) of \(notificationTimes.count) at \(timeString) every \(dayInterval) day(s)")
            
            scheduleReminder(at: timeString, dayInterval: dayInterval, index: index + 1, using: mgr)
        }
    }

    private func scheduleDailyReminder(at timeString: String, using mgr: AssignmentManager) {
        scheduleReminder(at: timeString, dayInterval: 1, index: 1, using: mgr)
    }
    
    private func scheduleReminder(at timeString: String, dayInterval: Int, index: Int, using mgr: AssignmentManager) {
        let center = UNUserNotificationCenter.current()
        
        // Create unique identifier for this notification
        let identifier = "reminder-\(timeString)-\(dayInterval)-\(index)"
        
        let content = UNMutableNotificationContent()
        content.title = mgr.taskCompleted ? "Activity completed!" : "Your Activity"
        content.body  = mgr.taskCompleted
            ? "New activity coming soon!"
            : "Work on: \(mgr.currentActivity?.name ?? "your activity")"
        content.sound = .default
        
        // Parse the time string (HH:mm format)
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return
        }
        
        // Create date components for the trigger
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // If interval > 1, use calendar-based calculations for the next trigger date
        if dayInterval > 1 {
            // Calculate the next trigger date based on the frequency
            let calendar = Calendar.current
            let now = Date()
            
            // Get today's date with the specified time
            var todayWithTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            
            // If today's time has already passed, start from tomorrow
            if todayWithTime < now {
                todayWithTime = calendar.date(byAdding: .day, value: 1, to: todayWithTime) ?? now
            }
            
            // Calculate how many days to add based on the frequency interval
            // to get the next occurrence date
            let daysSinceReference = calendar.component(.day, from: calendar.startOfDay(for: now))
            let daysToAdd = (dayInterval - (daysSinceReference % dayInterval)) % dayInterval
            
            if daysToAdd > 0 {
                todayWithTime = calendar.date(byAdding: .day, value: daysToAdd, to: todayWithTime) ?? now
            }
            
            // Extract date components for the trigger
            dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: todayWithTime)
        }
        
        // Create the trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        // Create and schedule the request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}

// Helper class to initialize and hold our shared resources
final class AppDependencies: ObservableObject {
    let dataController: DataController
    lazy var assignmentManager: AssignmentManager = {
        print("🔧 Initializing AssignmentManager")
        let manager = AssignmentManager(context: dataController.container.viewContext)
        print("🔧 AssignmentManager initialized with activity: \(manager.currentActivity?.name ?? "none")")
        
        // Store the shared instance
        AppDependencies.sharedAssignmentManager = manager
        
        return manager
    }()
    let notificationManager = NotificationManager.shared
    
    // Static reference for access from anywhere in the app (for debugging)
    static var sharedAssignmentManager: AssignmentManager?
    
    init() {
        print("🔧 AppDependencies initializing")
        
        // Initialize DataController
        dataController = DataController()
        print("🔧 DataController initialized")
        
        // Set up notification manager
        notificationManager.assignmentManager = assignmentManager
        notificationManager.requestAuthorization()
        notificationManager.scheduleAllNotifications(using: assignmentManager)
        print("🔧 Notification setup complete")
    }
}

@main
struct NewExperiencesApp: App {
    // Use a separate class to initialize dependencies
    @StateObject private var dependencies = AppDependencies()
    
    init() {
        print("📱 NewExperiencesApp initializing")
    }

    var body: some Scene {
        let dataContext = dependencies.dataController.container.viewContext
        let assignmentMgr = dependencies.assignmentManager
        
        print("📱 Building Scene")
        print("📱 Using manager: \(type(of: assignmentMgr))")
        
        return WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataContext)
                .environmentObject(assignmentMgr)
                .onAppear {
                    print("📱 ContentView.onAppear")
                }
        }
    }
}
