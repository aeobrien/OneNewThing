import SwiftUI

struct ActivityDetailView: View {
    let activity: Activity

    // Safely pull “notes” out of CoreData at runtime:
    private var notesText: String {
        (activity.value(forKey: "notes") as? String) ?? "No notes yet."
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(activity.name ?? "")
                    .font(.title)

                ScrollView {
                    Text(notesText)
                        .padding(.top)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
            }
        }
    }
}
