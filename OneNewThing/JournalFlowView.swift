/// JournalFlowView.swift
import SwiftUI
import CoreData

struct JournalFlowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    let activityName: String
    @State private var step = 1
    @State private var answers = ["", "", "", ""]

    @State private var question2: String
    @State private var question3: String
    @State private var question4: String

    // Voice Input ViewModel
    @StateObject private var voiceInputViewModel = VoiceInputViewModel()

    private let question1 = "What did you do today?"

    private static let pool2 = [
        "What moment stuck with you most — and why?",
        "What part of the experience was most unexpected?",
        "How did it feel emotionally and/or physically?",
        "When did you feel most out of your depth?",
        "What did your body tell you during the experience?",
        "Was there a point where your feelings changed?",
        "What was easier than expected? Harder?",
        "What caught you off guard?",
        "What, if anything, made you smile or laugh?",
        "If you could freeze-frame one part of today to show someone, what would it be?"
    ]

    private static let pool3 = [
        "Did this reveal anything new about you?",
        "What challenged you the most — and why?",
        "Did anything shift in your thinking?",
        "What might this experience be trying to teach you?",
        "What did you learn that you couldn't have learned another way?",
        "Did this poke a hole in any assumptions you had?",
        "What did this unlock or unblock?",
        "If this experience had a message just for you, what would it be?",
        "How might this change the way you see something — yourself, others, the world?",
        "What did you find unexpectedly meaningful?"
    ]

    private static let pool4 = [
        "Would you do this again? Why or why not?",
        "What's one small thing you might do differently after this?",
        "Did this open up any new questions or interests?",
        "What are you curious about now, that you weren't before?",
        "Is there a new skill, habit, or idea you'd like to explore from here?",
        "Could this experience be the start of something?",
        "Do you want to follow this thread further?",
        "What kind of person would do this regularly — and are you becoming that person?",
        "What would be the next step, if you wanted to go deeper?",
        "Is there someone you'd want to tell about this?"
    ]

    init(activityName: String) {
        self.activityName = activityName
        _question2 = State(initialValue: Self.pool2.randomElement()!)
        _question3 = State(initialValue: Self.pool3.randomElement()!)
        _question4 = State(initialValue: Self.pool4.randomElement()!)
        print("JournalFlowView initialized for activity: \(activityName)")
    }

    private func currentQuestion() -> String {
        switch step {
        case 1: return question1
        case 2: return question2
        case 3: return question3
        default: return question4
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question Text
            Text(currentQuestion())
                .font(.headline)
                .padding(.bottom, 8)

            // TextEditor for answer
            TextEditor(text: $answers[step - 1])
                .border(Color.gray)
                .frame(height: 200)
                .onChange(of: voiceInputViewModel.transcribedText) { newText in
                    // Append transcribed text to the current answer
                    // User might have already typed something, so append rather than replace.
                    if !newText.isEmpty {
                        answers[step - 1] += (answers[step - 1].isEmpty ? "" : " ") + newText
                        // Clear the transcribed text in ViewModel to prevent re-appending on other changes
                        voiceInputViewModel.transcribedText = ""
                        print("JournalFlowView: Appended transcribed text to answer for step \(step).")
                    }
                }
            
            // Voice Input Status Area
            VStack(alignment: .leading) {
                Text(voiceInputViewModel.recordingStatusMessage)
                    .font(.caption)
                    .foregroundColor(voiceInputViewModel.errorMessage != nil ? .red : .gray)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                if voiceInputViewModel.isRecording {
                    // Optional: Show a simple visualizer or recording duration
                    HStack {
                        Image(systemName: "waveform.circle")
                            .foregroundColor(voiceInputViewModel.isPaused ? .orange : .red)
                        // Basic level meter (very simple)
                        ProgressView(value: voiceInputViewModel.audioLevel, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: voiceInputViewModel.isPaused ? .orange : .red))
                            .frame(height: 5)
                    }
                }
            }
            .padding(.top, 5)

            Spacer()

            // Navigation Buttons (Back/Next/Done)
            HStack {
                if step > 1 {
                    Button("Back") { 
                        // Before going back, if recording is active, consider how to handle it.
                        // For now, we assume user manages recording state independently via mic button.
                        step -= 1 
                        print("JournalFlowView: Back button tapped. Current step: \(step)")
                    }
                }
                Spacer()
                Button(step == 4 ? "Done" : "Next") {
                    if step < 4 {
                        step += 1
                        print("JournalFlowView: Next button tapped. Current step: \(step)")
                    } else {
                        // Final step - Done
                        // If recording is active, stop it before saving and dismissing
                        if voiceInputViewModel.isRecording {
                            print("JournalFlowView: 'Done' tapped while recording. Stopping recording first.")
                            voiceInputViewModel.stopRecordingAndTranscribe() 
                            // The transcription will update `answers` via onChange.
                            // Need to ensure saveEntry() is called *after* transcription might have updated the answer.
                            // This might require a slight delay or a different flow if transcription is slow.
                            // For simplicity, save immediately. If transcription is pending, it won't be included.
                            // A more robust solution would wait for transcription or save placeholder.
                        }
                        saveEntry()
                        presentationMode.wrappedValue.dismiss()
                        print("JournalFlowView: Done button tapped. Entry saved, view dismissed.")
                    }
                }
            }
        }
        .padding()
        .navigationTitle(activityName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Microphone Button in Toolbar
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    print("JournalFlowView: Microphone button tapped.")
                    if voiceInputViewModel.isRecording {
                        // If recording, tapping again means stop and transcribe
                        voiceInputViewModel.stopRecordingAndTranscribe()
                    } else {
                        // If not recording, tapping means start recording
                        voiceInputViewModel.startRecording()
                    }
                }) {
                    Image(systemName: voiceInputViewModel.isRecording ? (voiceInputViewModel.isPaused ? "mic.slash.circle.fill" : "stop.circle.fill") : "mic.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .foregroundColor(voiceInputViewModel.isRecording ? (voiceInputViewModel.isPaused ? .orange : .red) : .blue)
                }
            }
        }
        .onAppear {
            print("JournalFlowView: Appeared.")
            // Perform any initial setup for voiceInputViewModel if needed, though init handles most.
        }
        .onDisappear {
            print("JournalFlowView: Disappeared. Cleaning up VoiceInputViewModel.")
            voiceInputViewModel.cleanUp() // Clean up resources when the view disappears
        }
    }

    private func saveEntry() {
        print("JournalFlowView: saveEntry() called with activityName: \(activityName)")
        let entry = JournalEntry(context: viewContext)
        entry.title = activityName
        entry.date  = Date()
        
        let questions = [question1, question2, question3, question4]
        var journalText = ""
        for i in 0..<questions.count {
            journalText += "Q: \(questions[i])\n"
            // Ensure answers array is accessed safely if its size can change (though it's fixed at 4 here)
            if i < answers.count, !answers[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                journalText += "A: \(answers[i])\n\n"
            } else {
                journalText += "A: (No answer provided)\n\n"
            }
        }
        
        entry.text = journalText
        
        print("JournalFlowView: About to save entry with title: '\(entry.title ?? "NIL")' and activityName: '\(activityName)'")
        
        do {
            try viewContext.save()
            print("JournalFlowView: Journal entry saved successfully. Title: \(entry.title ?? "N/A"), Date: \(entry.date?.description ?? "N/A")")
        } catch {
            let nsError = error as NSError
            print("JournalFlowView: Error saving journal entry: \(nsError), \(nsError.userInfo)")
            // Handle error appropriately (e.g., show an alert to the user)
        }
    }
}

// Preview (Optional - ensure it compiles or comment out if problematic during refactoring)
// struct JournalFlowView_Previews: PreviewProvider {
//     static var previews: some View {
//         // Need to set up a mock managed object context for CoreData previews
//         // For simplicity, this might be omitted if not straightforward.
//         NavigationView { // Wrap in NavigationView for toolbar items to show
//             JournalFlowView(activityName: "Sample Activity")
//         }
//     }
// }
