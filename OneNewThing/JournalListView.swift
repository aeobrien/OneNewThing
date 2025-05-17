/// JournalListView.swift
import SwiftUI
import CoreData

struct JournalListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<JournalEntry>

    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedEntry: JournalEntry?

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    Button(action: { selectedEntry = entry }) {
                        VStack(alignment: .leading) {
                            Text(entry.title ?? "Untitled")
                                .font(.headline)
                            Text(entry.date!, style: .date)
                                .font(.caption)
                            Text(entry.text ?? "")
                                .lineLimit(2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    idx.map { entries[$0] }.forEach(viewContext.delete)
                    try? viewContext.save()
                }
            }
            .navigationTitle("Journal")
            .toolbar { EditButton() }
            .sheet(item: $selectedEntry) { entry in
                EditJournalView(entry: entry)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}
