/// AssignmentManager.swift
import Foundation
import CoreData
import Combine

class AssignmentManager: ObservableObject {
    @Published var currentActivity: Activity?
    @Published var alternativeOptions: [Activity] = []
    @Published var alternativeOffered: Bool = false
    @Published var taskCompleted = false
    private let ctx: NSManagedObjectContext
    
    // Get the period days from UserDefaults, defaulting to 7
    var periodDays: Int {
        let days = UserDefaults.standard.integer(forKey: "activityPeriodDays")
        return days > 0 ? days : 7
    }

    init(context: NSManagedObjectContext) {
        ctx = context
        loadCurrent()
    }

    func loadCurrent() {
        let last = UserDefaults.standard.object(forKey: "lastAssignmentDate") as? Date ?? .distantPast
        guard let next = Calendar.current.date(byAdding: .day, value: periodDays, to: last) else { return }
        if Date() >= next {
            assignNew()
        } else {
            loadSaved()
        }
    }

    private func assignNew() {
        let req: NSFetchRequest<Activity> = Activity.fetchRequest()
        req.predicate = NSPredicate(format: "isIncluded == YES AND isCompleted == NO")
        if let all = try? ctx.fetch(req), let pick = all.randomElement() {
            currentActivity = pick
            UserDefaults.standard.set(Date(), forKey: "lastAssignmentDate")
            UserDefaults.standard.set(pick.name, forKey: "currentActivityName")
            alternativeOffered = false
            alternativeOptions = []
            taskCompleted = false
        }
    }

    private func loadSaved() {
        if let name = UserDefaults.standard.string(forKey: "currentActivityName") {
            let req: NSFetchRequest<Activity> = Activity.fetchRequest()
            req.predicate = NSPredicate(format: "name == %@", name)
            if let activity = (try? ctx.fetch(req))?.first {
                currentActivity = activity
                taskCompleted = activity.isCompleted
            }
        }
    }
    
    /// Refreshes the period timing without changing the current activity
    func refreshPeriod() {
        // The start date was updated in UserDefaults by the SettingsView
        // Just notify observers that a change occurred
        objectWillChange.send()
    }

    /// Offer exactly two random alternatives plus current activity
    func offerAlternatives() {
        guard !alternativeOffered, let current = currentActivity else { return }
        let req: NSFetchRequest<Activity> = Activity.fetchRequest()
        req.predicate = NSPredicate(format: "isIncluded == YES AND isCompleted == NO AND name != %@", current.name ?? "")
        if let all = try? ctx.fetch(req), all.count >= 2 {
            let two = all.shuffled().prefix(2)
            alternativeOptions = [current] + two
        } else {
            alternativeOptions = [current]
        }
        alternativeOffered = true
    }

    /// Select one of the offered activities
    func selectAlternative(_ act: Activity) {
        currentActivity = act
        UserDefaults.standard.set(act.name, forKey: "currentActivityName")
    }

    /// Mark the current task completed
    func completeTask() {
        if let act = currentActivity {
            act.isCompleted = true
            try? ctx.save()
            taskCompleted = true
        }
    }
}
