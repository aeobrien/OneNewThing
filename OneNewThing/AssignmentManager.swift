/// AssignmentManager.swift
import Foundation
import CoreData
import Combine

class AssignmentManager: ObservableObject {
    @Published var currentActivity: Activity?
    @Published var alternativeOptions: [Activity] = []
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
                alternativeOptions = []
                taskCompleted = false
                isOverdue = false
                
                // Generate and save alternatives for this activity
                generateAndSaveAlternatives(for: pick, from: all)
                
                print("📊 Assigned new activity: \(pick.name ?? "unknown")")
                
                // Reschedule notifications to reflect the new activity
                NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
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
                    
                    // Generate alternatives for fallback activity too
                    if let allFallback = try? ctx.fetch(fallbackReq) {
                        generateAndSaveAlternatives(for: fallbackAct, from: allFallback)
                    }
                    
                    // Reschedule notifications for fallback activity
                    NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
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
            alternativeOptions = []
            taskCompleted = false
            isOverdue = false
            
            // Generate and save alternatives for this activity too
            generateAndSaveAlternatives(for: pick, from: all)
            
            // Reschedule notifications to reflect the new activity
            NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
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
            // Calculate how much time we were overdue
            let now = Date()
            if let deadline = activityDeadline {
                let overdueTime = now.timeIntervalSince(deadline)
                
                // Set new assignment date to now minus the overdue time
                // This gives us a full period minus the overdue time
                let newStartDate = Calendar.current.date(byAdding: .second, value: -Int(overdueTime), to: now) ?? now
                UserDefaults.standard.set(newStartDate, forKey: "lastAssignmentDate")
            } else {
                // Fallback: just set to now if we can't calculate deadline
                UserDefaults.standard.set(now, forKey: "lastAssignmentDate")
            }
            
            // Now assign a new activity
            assignNew()
        }
    }
    
    /// Skip the current activity at any time and get a new one
    func skipActivity() {
        if let _ = currentActivity {
            // Reset the timer to start a new period from now
            UserDefaults.standard.set(Date(), forKey: "lastAssignmentDate")
            
            // Assign a new activity
            assignNew()
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

    /// Generate and save alternatives for the current activity
    private func generateAndSaveAlternatives(for activity: Activity, from allActivities: [Activity]) {
        let otherActivities = allActivities.filter { $0.objectID != activity.objectID }
        
        if otherActivities.count >= 3 {
            let threeAlternatives = otherActivities.shuffled().prefix(3)
            let alternativeNames = threeAlternatives.map { $0.name ?? "" }
            
            // Save the alternative names to UserDefaults
            UserDefaults.standard.set(alternativeNames, forKey: "currentActivityAlternatives")
            print("📊 Saved alternatives: \(alternativeNames)")
        } else if otherActivities.count > 0 {
            // If we have fewer than 3, use what we have
            let alternativeNames = otherActivities.map { $0.name ?? "" }
            UserDefaults.standard.set(alternativeNames, forKey: "currentActivityAlternatives")
            print("📊 Saved alternatives (fewer than 3): \(alternativeNames)")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentActivityAlternatives")
            print("📊 Not enough activities for alternatives")
        }
    }
    
    /// Load saved alternatives from UserDefaults
    private func loadSavedAlternatives() {
        guard let current = currentActivity else { return }
        
        if let alternativeNames = UserDefaults.standard.stringArray(forKey: "currentActivityAlternatives") {
            var options: [Activity] = []
            
            // Fetch the alternative activities by name (excluding current)
            for name in alternativeNames {
                let req: NSFetchRequest<Activity> = Activity.fetchRequest()
                req.predicate = NSPredicate(format: "name == %@ AND isIncluded == YES AND isCompleted == NO", name)
                if let activity = try? ctx.fetch(req).first {
                    options.append(activity)
                }
            }
            
            alternativeOptions = options
            print("📊 Loaded saved alternatives: \(alternativeNames)")
        } else {
            // If no saved alternatives, generate them now
            let req: NSFetchRequest<Activity> = Activity.fetchRequest()
            req.predicate = NSPredicate(format: "isIncluded == YES AND isCompleted == NO")
            if let all = try? ctx.fetch(req) {
                generateAndSaveAlternatives(for: current, from: all)
                loadSavedAlternatives() // Recursively load what we just saved
            }
        }
    }
    
    /// Offer three random alternatives (excluding current activity)
    func offerAlternatives() {
        guard let current = currentActivity else { return }
        
        // Generate fresh alternatives each time for unlimited re-rolls
        let req: NSFetchRequest<Activity> = Activity.fetchRequest()
        req.predicate = NSPredicate(format: "isIncluded == YES AND isCompleted == NO")
        if let all = try? ctx.fetch(req) {
            generateAndSaveAlternatives(for: current, from: all)
            loadSavedAlternatives()
        }
    }

    /// Select one of the offered activities
    func selectAlternative(_ act: Activity) {
        // Only change if we actually selected a different activity
        if act.objectID != currentActivity?.objectID {
            currentActivity = act
            UserDefaults.standard.set(act.name, forKey: "currentActivityName")
            taskCompleted = false
            
            // Generate new alternatives for the newly selected activity
            let req: NSFetchRequest<Activity> = Activity.fetchRequest()
            req.predicate = NSPredicate(format: "isIncluded == YES AND isCompleted == NO")
            if let all = try? ctx.fetch(req) {
                generateAndSaveAlternatives(for: act, from: all)
            }
            
            // Reschedule notifications to reflect the new activity
            NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
        }
        // Clear the options either way
        alternativeOptions = []
    }

    /// Mark the current task completed
    func completeTask() {
        if let act = currentActivity {
            act.isCompleted = true
            try? ctx.save()
            taskCompleted = true
            
            // Reschedule notifications to reflect the new state
            NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
            
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
            
            // Reschedule notifications to reflect the new state
            NotificationCenter.default.post(name: Notification.Name("RescheduleNotifications"), object: nil)
        }
    }
    
    /// Refresh UI state to match current activity state
    func refreshState() {
        if let act = currentActivity {
            taskCompleted = act.isCompleted
            objectWillChange.send()
        }
    }
    
    /// Set a specific activity as current while maintaining the period timer
    func setActivityMaintainingPeriod(_ activity: Activity, alternatives: [Activity]) {
        currentActivity = activity
        // Do NOT update the lastAssignmentDate - this keeps the original timer
        UserDefaults.standard.set(activity.name, forKey: "currentActivityName")
        alternativeOptions = []
        taskCompleted = activity.isCompleted
        
        // Generate and save alternatives for this activity
        generateAndSaveAlternatives(for: activity, from: alternatives)
        
        // Notify observers of the change
        objectWillChange.send()
    }
}
