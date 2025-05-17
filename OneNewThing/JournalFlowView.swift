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
            Text(currentQuestion())
                .font(.headline)
                .padding(.bottom, 8)

            TextEditor(text: $answers[step - 1])
                .border(Color.gray)
                .frame(height: 200)

            Spacer()

            HStack {
                if step > 1 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                Button(step == 4 ? "Done" : "Next") {
                    if step < 4 {
                        step += 1
                    } else {
                        saveEntry()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .padding()
        .navigationTitle(activityName)
    }

    private func saveEntry() {
        let entry = JournalEntry(context: viewContext)
        entry.title = activityName
        entry.date  = Date()
        
        // Get all questions
        let questions = [question1, question2, question3, question4]
        
        // Format with both questions and answers
        var journalText = ""
        for i in 0..<questions.count {
            // Add question
            journalText += "Q: \(questions[i])\n"
            // Add answer (if any)
            journalText += "A: \(answers[i])\n\n"
        }
        
        entry.text = journalText
        try? viewContext.save()
    }
}
