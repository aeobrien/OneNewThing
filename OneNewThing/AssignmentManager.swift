/// AssignmentManager.swift
import Foundation
import CoreData
import Combine

class AssignmentManager: ObservableObject {
    @Published var currentActivity: Activity?
    @Published var alternativeOptions: [Activity] = []
    @Published var alternativeOffered: Bool = false
    @Published var taskCompleted = false
    @Published var isOverdue = false
    private let ctx: NSManagedObjectContext
    
    // Get the period days from UserDefaults, defaulting to 7
    var periodDays: Int {
        let days = UserDefaults.standard.integer(forKey: "activityPeriodDays")
        return days > 0 ? days : 7
    }
    
    // Calculate the deadline for the current activity
    var activityDeadline: Date? {
        guard let lastAssignmentDate = UserDefaults.standard.object(forKey: "lastAssignmentDate") as? Date else {
            return nil
        }
        return Calendar.current.date(byAdding: .day, value: periodDays, to: lastAssignmentDate)
    }

    init(context: NSManagedObjectContext) {
        ctx = context
        loadCurrent()
    }

    func loadCurrent() {
        print("📊 loadCurrent() called")
        let last = UserDefaults.standard.object(forKey: "lastAssignmentDate") as? Date ?? .distantPast
        guard let next = Calendar.current.date(byAdding: .day, value: periodDays, to: last) else { return }
        
        if Date() >= next {
            // We're past the deadline, but don't automatically assign a new task
            // Instead, mark as overdue and let the user decide
            isOverdue = true
            loadSaved()
        } else {
            isOverdue = false
            loadSaved()
        }
        
        // If we still don't have a current activity after loading saved, assign a new one
        if currentActivity == nil {
            print("📊 No current activity found, assigning new one")
            assignNew()
        }
    }

    // This assigns a new activity and resets the last assignment date to NOW
    private func assignNew() {
        print("📊 assignNew() called")
        let req: NSFetchRequest<Activity> = Activity.fetchRequest()
        req.predicate = NSPredicate(format: "isIncluded == YES AND isCompleted == NO")
        
        do {
            let all = try ctx.fetch(req)
            print("📊 Found \(all.count) eligible activities")
            
            if let pick = all.randomElement() {
                currentActivity = pick
                UserDefaults.standard.set(Date(), forKey: "lastAssignmentDate")
                UserDefaults.standard.set(pick.name, forKey: "currentActivityName")
                alternativeOffered = false
                alternativeOptions = []
                taskCompleted = false
                isOverdue = false
                print("📊 Assigned new activity: \(pick.name ?? "unknown")")
            } else {
                print("📊 ERROR: No eligible activities available!")
                // If no eligible activities, try to get any activity that's included
                let fallbackReq: NSFetchRequest<Activity> = Activity.fetchRequest()
                fallbackReq.predicate = NSPredicate(format: "isIncluded == YES")
                
                if let fallbackAct = try? ctx.fetch(fallbackReq).randomElement() {
                    print("📊 Using fallback activity: \(fallbackAct.name ?? "unknown")")
                    currentActivity = fallbackAct
                    UserDefaults.standard.set(Date(), forKey: "lastAssignmentDate")
                    UserDefaults.standard.set(fallbackAct.name, forKey: "currentActivityName")
                }
            }
        } catch {
            print("📊 ERROR fetching activities: \(error.localizedDescription)")
        }
    }
    
    // This assigns a new activity but maintains the original time period
    func assignNewMaintainingPeriod() {
        let req: NSFetchRequest<Activity> = Activity.fetchRequest()
        req.predicate = NSPredicate(format: "isIncluded == YES AND isCompleted == NO")
        if let all = try? ctx.fetch(req), let pick = all.randomElement() {
            currentActivity = pick
            // Do NOT update the lastAssignmentDate - this keeps the original timer
            UserDefaults.standard.set(pick.name, forKey: "currentActivityName")
            alternativeOffered = false
            alternativeOptions = []
            taskCompleted = false
            isOverdue = false
        }
    }

    private func loadSaved() {
        print("📊 loadSaved() called")
        if let name = UserDefaults.standard.string(forKey: "currentActivityName") {
            print("📊 Attempting to load saved activity: \(name)")
            let req: NSFetchRequest<Activity> = Activity.fetchRequest()
            req.predicate = NSPredicate(format: "name == %@", name)
            do {
                if let activity = try ctx.fetch(req).first {
                    currentActivity = activity
                    // Ensure taskCompleted is synced with the activity's isCompleted state
                    taskCompleted = activity.isCompleted
                    print("📊 Loaded saved activity: \(activity.name ?? "unknown"), completed: \(activity.isCompleted)")
                    
                    // Check if we're overdue
                    checkOverdueStatus()
                } else {
                    print("📊 ERROR: Saved activity '\(name)' not found in database")
                }
            } catch {
                print("📊 ERROR fetching saved activity: \(error.localizedDescription)")
            }
        } else {
            print("📊 No saved activity name found in UserDefaults")
        }
    }
    
    // Check if the current activity is overdue
    private func checkOverdueStatus() {
        if let deadline = activityDeadline {
            isOverdue = Date() > deadline && !taskCompleted
        } else {
            isOverdue = false
        }
    }
    
    /// Skip the current activity (when overdue) and get a new one
    func skipOverdueActivity() {
        if let act = currentActivity, isOverdue {
            // Leave the activity as not completed
            // Get a new activity but maintain the original time period
            assignNewMaintainingPeriod()
        }
    }
    
    /// Refreshes the period timing without changing the current activity
    func refreshPeriod() {
        // The start date was updated in UserDefaults by the SettingsView
        // Just notify observers that a change occurred
        objectWillChange.send()
        
        // Check if we're now overdue with the new settings
        checkOverdueStatus()
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
            
            // If overdue, prepare the next activity immediately but maintain the original timer
            if isOverdue {
                // Schedule the next activity for after the journal entry
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.assignNewMaintainingPeriod()
                }
            }
        }
    }
    
    /// Mark the current task as not completed
    func uncompleteTask() {
        if let act = currentActivity {
            act.isCompleted = false
            try? ctx.save()
            taskCompleted = false
            objectWillChange.send()
        }
    }
    
    /// Refresh UI state to match current activity state
    func refreshState() {
        if let act = currentActivity {
            taskCompleted = act.isCompleted
            objectWillChange.send()
        }
    }
}
