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
                        .font(.pingFangSemibold(size: 28))
                        .foregroundColor(Color("AccentColor"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                    Text("New activity in:")
                        .font(.pingFangLight(size: 18))
                        .foregroundColor(.secondary)
                    Text(formatTimeInterval(timeRemaining))
                        .font(.system(size: 36, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .padding(.bottom, 40)
                        .animation(.easeInOut(duration: 0.5), value: timeRemaining)
                }
                .padding(.horizontal)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            } else if assignmentManager.isOverdue {
                // Show overdue UI (including skip button, activity name, etc)
                Text("Activity Overdue!")
                    .font(.pingFangSemibold(size: 24))
                    .foregroundColor(.red)
                if let activity = assignmentManager.currentActivity {
                    Text(activity.name ?? "No activity")
                        .font(.pingFangMedium(size: 22))
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                        .onTapGesture {
                            selectedActivity = activity
                        }
                    // Timer display
                    Text("Overdue: \(formatTimeInterval(timeOverdue))")
                        .font(.pingFangRegular(size: 16))
                        .foregroundColor(.red)
                        .monospacedDigit()
                        .padding(.top, 4)
                    // Three buttons in one line
                    HStack(spacing: 12) {
                        // Dice button (left)
                        Button {
                            assignmentManager.offerAlternatives()
                            showOptions = true
                        } label: {
                            Image(systemName: "dice.fill")
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.primary.opacity(0.05))
                                )
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Done button (center)
                        LongPressButton(duration: 3) {
                            assignmentManager.completeTask()
                            showJournal = true
                        } label: {
                            Text("Done")
                                .font(.pingFangSemibold(size: 17))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color("AccentColor"))
                                )
                                .foregroundColor(.white)
                                .shadow(color: Color("AccentColor").opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        
                        // Skip button (right)
                        Button {
                            assignmentManager.skipOverdueActivity()
                        } label: {
                            Text("Skip")
                                .font(.pingFangMedium(size: 16))
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                )
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.top, 12)
                } else {
                    Text("No activity assigned")
                        .font(.pingFangLight(size: 18))
                        .foregroundColor(.gray)
                }
            } else {
                // Show normal UI (dice, countdown, completion button, etc)
                Text("Current Activity")
                    .font(.pingFangSemibold(size: 24))
                    .foregroundColor(.primary.opacity(0.8))
                    .onLongPressGesture(minimumDuration: 3) {
                        print("⚙️ Long press detected on Current Activity title")
                        showActivityPicker = true
                    }
                if let activity = assignmentManager.currentActivity {
                    Text(activity.name ?? "No activity")
                        .font(.pingFangMedium(size: 22))
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("AccentColor").opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("AccentColor").opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.primary.opacity(0.05), radius: 5, x: 0, y: 2)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedActivity = activity
                            }
                        }
                    // Timer display
                    Text("Time remaining: \(formatTimeInterval(timeRemaining))")
                        .font(.pingFangRegular(size: 16))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .animation(.easeInOut(duration: 0.5), value: timeRemaining)
                    
                    // Three buttons in one line
                    HStack(spacing: 12) {
                        // Dice button (left)
                        Button {
                            assignmentManager.offerAlternatives()
                            showOptions = true
                        } label: {
                            Image(systemName: "dice.fill")
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.primary.opacity(0.05))
                                )
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Done button (center)
                        LongPressButton(duration: 3) {
                            assignmentManager.completeTask()
                            showJournal = true
                        } label: {
                            Text("Done")
                                .font(.pingFangSemibold(size: 17))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color("AccentColor"))
                                )
                                .foregroundColor(.white)
                                .shadow(color: Color("AccentColor").opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        
                        // Skip button (right)
                        Button {
                            assignmentManager.skipActivity()
                        } label: {
                            Text("Skip")
                                .font(.pingFangMedium(size: 16))
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                )
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.top, 12)
                } else {
                    Text("No activity assigned")
                        .font(.pingFangLight(size: 18))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        // Journal entry sheet
        .sheet(isPresented: $showJournal) {
            NavigationStack {
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
        // Action sheet for alternative activities
        .actionSheet(isPresented: $showOptions) {
            ActionSheet(
                title: Text("Choose your activity").font(.pingFangMedium(size: 18)),
                buttons: assignmentManager.alternativeOptions.map { act in
                    .default(Text(act.name ?? "").font(.pingFangRegular(size: 16))) {
                        assignmentManager.selectAlternative(act)
                    }
                } + [.cancel()]
            )
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

// Add a custom button style for subtle animations
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
