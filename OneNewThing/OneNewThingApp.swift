// NewExperiencesApp.swift
import SwiftUI
import UserNotifications

@main
struct NewExperiencesApp: App {
    @StateObject private var dataController: DataController
    @StateObject private var assignmentManager: AssignmentManager

    init() {
        let dc = DataController()
        _dataController    = StateObject(wrappedValue: dc)
        _assignmentManager = StateObject(wrappedValue: AssignmentManager(context: dc.container.viewContext))

        requestNotifications()
        scheduleDailyReminder(using: _assignmentManager.wrappedValue)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(assignmentManager)   // ← make sure this is here once, at the root
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleDailyReminder(using mgr: AssignmentManager) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])

        let content = UNMutableNotificationContent()
        content.title = mgr.taskCompleted ? "Activity completed!" : "Weekly Experience"
        content.body  = mgr.taskCompleted
            ? "New activity in:"
            : "Work on: \(mgr.currentActivity?.name ?? "your activity")"

        var dc = DateComponents(); dc.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let req = UNNotificationRequest(
            identifier: "dailyReminder",
            content: content,
            trigger: trigger
        )
        center.add(req)
    }
}
