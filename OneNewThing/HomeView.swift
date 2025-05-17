/// HomeView.swift
import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject var assignmentManager: AssignmentManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var timeRemaining: TimeInterval = 0
    @State private var selectedActivity: Activity?
    @State private var showJournal = false
    @State private var showOptions = false
    @State private var showLimitAlert = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            Text(assignmentManager.taskCompleted ? "Activity completed! New activity in:" : "This Week’s Activity")
                .font(.headline)

            Text(assignmentManager.currentActivity?.name ?? "Loading…")
                .font(.title)
                .multilineTextAlignment(.center)
                .onTapGesture {
                    if let act = assignmentManager.currentActivity {
                        selectedActivity = act
                    }
                }

            Text(countdownString())
                .font(.subheadline)
                .monospacedDigit()

            // Dice for alternatives
            Button {
                if !assignmentManager.alternativeOffered {
                    assignmentManager.offerAlternatives()
                    showOptions = true
                } else {
                    showLimitAlert = true
                }
            } label: {
                Image(systemName: "dice.fill")
                    .font(.largeTitle)
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
                    message: Text("You can only re-roll once per week."),
                    dismissButton: .default(Text("OK"))
                )
            }

            // Completion button + journal flow
            LongPressButton(duration: 3) {
                assignmentManager.completeTask()
                showJournal = true
            } label: {
                Text("I've done this!")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            // JournalFlow sheet
            .sheet(isPresented: $showJournal) {
                if let act = assignmentManager.currentActivity {
                    NavigationStack {
                        JournalFlowView(activityName: act.name ?? "Activity")
                            .environment(\.managedObjectContext, viewContext)
                    }
                }
            }
            // Notes detail sheet
            .sheet(item: $selectedActivity) { act in
                ActivityDetailView(activity: act)
            }
        }
        .padding()
        .onAppear { updateTime() }
        .onReceive(timer) { _ in updateTime() }
    }

    // MARK: - Helpers

    private func updateTime() {
        let last = UserDefaults.standard.object(forKey: "lastAssignmentDate") as? Date ?? .distantPast
        guard let deadline = Calendar.current.date(byAdding: .day, value: 7, to: last) else { return }
        timeRemaining = max(0, deadline.timeIntervalSince(Date()))
    }

    private func countdownString() -> String {
        let total = Int(timeRemaining)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02dd %02dh %02dm %02ds", days, hours, mins, secs)
    }
}
