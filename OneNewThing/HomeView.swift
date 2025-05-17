/// HomeView.swift
import SwiftUI
import CoreData

// Small diagnostic test view
struct DiagnosticView: View {
    @EnvironmentObject var assignmentManager: AssignmentManager
    
    var body: some View {
        VStack {
            Text("DIAGNOSTIC VIEW")
                .font(.headline)
                .foregroundColor(.black)
            
            Text("Manager present: YES")
                .foregroundColor(.black)
            
            if let activity = assignmentManager.currentActivity {
                Text("Activity: \(activity.name ?? "unnamed")")
                    .foregroundColor(.black)
            } else {
                Text("No activity loaded")
                    .foregroundColor(.red)
            }
            
            Text("Task completed: \(assignmentManager.taskCompleted ? "YES" : "NO")")
                .foregroundColor(.black)
            Text("Is overdue: \(assignmentManager.isOverdue ? "YES" : "NO")")
                .foregroundColor(.black)
            
            // Fallback button
            Button("Refresh UI") {
                AppDependencies.sharedAssignmentManager?.objectWillChange.send()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.yellow)
        .cornerRadius(10)
        .onAppear {
            print("📱 DiagnosticView appeared with manager: \(type(of: assignmentManager))")
            print("📱 Current activity: \(assignmentManager.currentActivity?.name ?? "nil")")
        }
    }
}

struct SimpleHomeView: View {
    @EnvironmentObject var assignmentManager: AssignmentManager
    @State private var timeRemaining: TimeInterval = 0
    @State private var timeOverdue: TimeInterval = 0
    @State private var showJournal = false
    @State private var showOptions = false
    @State private var showLimitAlert = false
    @State private var selectedActivity: Activity?
    @State private var lastUpdateTime: Date = Date()
    @State private var showActivityPicker = false
    @State private var activityCompletedObserver: NSKeyValueObservation?
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            if assignmentManager.taskCompleted || (assignmentManager.currentActivity?.isCompleted ?? false) {
                // Show only the completed message and countdown
                VStack(spacing: 16) {
                    Text("Activity Completed!")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                    Text("New activity in:")
                        .font(.headline)
                    Text(formatTimeInterval(timeRemaining))
                        .font(.largeTitle)
                        .monospacedDigit()
                        .padding(.bottom, 40)
                }
            } else if assignmentManager.isOverdue {
                // Show overdue UI (including skip button, activity name, etc)
                Text("Activity Overdue!")
                    .font(.title2)
                    .foregroundColor(.red)
                if let activity = assignmentManager.currentActivity {
                    Text(activity.name ?? "No activity")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .onTapGesture {
                            selectedActivity = activity
                        }
                    // Timer display
                    Text("Overdue: \(formatTimeInterval(timeOverdue))")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .monospacedDigit()
                    // Skip button for overdue activities
                    Button {
                        assignmentManager.skipOverdueActivity()
                    } label: {
                        Text("Skip this activity")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                } else {
                    Text("No activity assigned")
                        .foregroundColor(.gray)
                }
            } else {
                // Show normal UI (dice, countdown, completion button, etc)
                Text("Current Activity")
                    .font(.title2)
                    .onLongPressGesture(minimumDuration: 3) {
                        print("⚙️ Long press detected on Current Activity title")
                        showActivityPicker = true
                    }
                if let activity = assignmentManager.currentActivity {
                    Text(activity.name ?? "No activity")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .onTapGesture {
                            selectedActivity = activity
                        }
                    // Dice/alternative button
                    Button {
                        if !assignmentManager.alternativeOffered {
                            assignmentManager.offerAlternatives()
                            showOptions = true
                        } else {
                            showLimitAlert = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "dice.fill")
                            Text("Try an alternative")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .actionSheet(isPresented: $showOptions) {
                        ActionSheet(
                            title: Text("Choose your activity"),
                            buttons: assignmentManager.alternativeOptions.map { act in
                                .default(Text(act.name ?? "")) {
                                    assignmentManager.selectAlternative(act)
                                }
                            } + [.cancel()]
                        )
                    }
                    .alert(isPresented: $showLimitAlert) {
                        Alert(
                            title: Text("No more alternatives"),
                            message: Text("You can only re-roll once per period."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                    // Timer display
                    Text("Time remaining: \(formatTimeInterval(timeRemaining))")
                        .font(.subheadline)
                        .monospacedDigit()
                    // Complete button
                    VStack(spacing: 12) {
                        LongPressButton(duration: 3) {
                            assignmentManager.completeTask()
                            showJournal = true
                        } label: {
                            Text("I've done this!")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Text("No activity assigned")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        // Journal entry sheet
        .sheet(isPresented: $showJournal) {
            NavigationView {
                JournalFlowView(activityName: assignmentManager.currentActivity?.name ?? "Activity")
            }
        }
        // Activity detail sheet
        .sheet(item: $selectedActivity) { activity in
            NavigationView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(activity.name ?? "Activity")
                        .font(.title)
                        .padding(.horizontal)
                    
                    if let category = activity.category?.name {
                        Text("Category: \(category)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    if let notes = activity.notes, !notes.isEmpty {
                        Text("Notes:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text(notes)
                            .padding(.horizontal)
                    } else {
                        Text("No notes available")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
                .navigationTitle("Activity Details")
                .navigationBarItems(trailing: Button("Done") {
                    selectedActivity = nil
                })
            }
        }
        // Activity picker sheet for testing
        .sheet(isPresented: $showActivityPicker) {
            ActivityPickerView()
        }
        .onAppear {
            print("📱 SimpleHomeView appeared with activity: \(assignmentManager.currentActivity?.name ?? "none")")
            lastUpdateTime = Date()
            updateTime()
            
            // Ensure we update taskCompleted based on current activity.isCompleted
            if let activity = assignmentManager.currentActivity {
                assignmentManager.taskCompleted = activity.isCompleted
                
                // Improve observer to handle both completion and uncompletion
                activityCompletedObserver = activity.observe(\Activity.isCompleted, options: [.new]) { _, change in
                    if let newValue = change.newValue {
                        // Update assignmentManager based on observed value
                        DispatchQueue.main.async {
                            assignmentManager.taskCompleted = newValue
                            print("⚙️ Activity completion state changed to: \(newValue)")
                            // Ensure view updates
                            assignmentManager.objectWillChange.send()
                        }
                    }
                }
            }
        }
        .onDisappear {
            if let observer = activityCompletedObserver {
                observer.invalidate()
                activityCompletedObserver = nil
            }
        }
        .onReceive(timer) { _ in 
            // Only update if at least 1 second has passed
            let now = Date()
            if now.timeIntervalSince(lastUpdateTime) >= 1.0 {
                lastUpdateTime = now
                updateTime() 
            }
        }
    }
    
    // MARK: - Timer Functions
    
    private func updateTime() {
        let last = UserDefaults.standard.object(forKey: "lastAssignmentDate") as? Date ?? .distantPast
        let periodDays = UserDefaults.standard.integer(forKey: "activityPeriodDays") > 0 ? 
            UserDefaults.standard.integer(forKey: "activityPeriodDays") : 7
        
        guard let deadline = Calendar.current.date(byAdding: .day, value: periodDays, to: last) else { return }
        
        let now = Date()
        let isOverdueNow = now > deadline && !assignmentManager.taskCompleted
        
        if isOverdueNow {
            // We're overdue
            timeOverdue = now.timeIntervalSince(deadline)
            timeRemaining = 0
            
            // Only update manager flag if it changed
            if !assignmentManager.isOverdue {
                assignmentManager.isOverdue = true
            }
        } else {
            // Normal countdown
            timeRemaining = max(0, deadline.timeIntervalSince(now))
            timeOverdue = 0
            
            // Only update manager flag if it changed
            if assignmentManager.isOverdue && !assignmentManager.taskCompleted {
                assignmentManager.isOverdue = false
            }
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
    }
}

// Original HomeView - keep it for reference but don't use it yet
struct HomeView: View {
    @EnvironmentObject var assignmentManager: AssignmentManager
    
    var body: some View {
        // Use the simplified version
        SimpleHomeView()
    }
}
