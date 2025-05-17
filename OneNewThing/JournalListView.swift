/// JournalListView.swift
import SwiftUI
import CoreData

struct SimpleJournalListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<JournalEntry>

    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        List {
            if entries.isEmpty {
                Text("No journal entries yet")
                    .foregroundColor(.gray)
                    .italic()
                    .padding()
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title ?? "Untitled")
                            .font(.headline)
                        Text(entry.date ?? Date(), style: .date)
                            .font(.caption)
                        Text(entry.text ?? "")
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            print("📔 SimpleJournalListView appeared with \(entries.count) entries")
        }
    }
}

// Original view now uses the simplified version
struct JournalListView: View {
    var body: some View {
        SimpleJournalListView()
    }
}
