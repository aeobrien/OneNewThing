/// JournalListView.swift
import SwiftUI
import CoreData

struct SimpleJournalListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<JournalEntry>

    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedEntry: JournalEntry?

    var body: some View {
        ZStack {
            // Background
            Color.primary.opacity(0.03)
                .edgesIgnoringSafeArea(.all)
            
            if entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.bottom, 8)
                    
                    Text("No journal entries yet")
                        .font(.pingFangMedium(size: 18))
                        .foregroundColor(.gray)
                    
                    Text("Your reflections will appear here")
                        .font(.pingFangLight(size: 15))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(entries) { entry in
                        JournalEntryRow(entry: entry)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture {
                                selectedEntry = entry
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete(perform: deleteEntries)
                    .listRowBackground(Color.clear)
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(item: $selectedEntry) { entry in
            JournalDetailView(entry: entry)
        }
        .onAppear {
            // Apply custom list style
            UITableView.appearance().backgroundColor = UIColor.clear
            UITableView.appearance().separatorStyle = .none
            
            print("📔 SimpleJournalListView appeared with \(entries.count) entries")
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            viewContext.delete(entry)
        }
        
        do {
            try viewContext.save()
            print("📔 Deleted \(offsets.count) journal entries")
        } catch {
            print("📔 Error deleting journal entries: \(error)")
        }
    }
}

struct JournalEntryRow: View {
    @ObservedObject var entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let activityName = entry.title, !activityName.isEmpty {
                Text(activityName)
                    .font(.pingFangSemibold(size: 20))
                    .foregroundColor(.primary)
            } else {
                Text("Untitled Activity")
                    .font(.pingFangSemibold(size: 20))
                    .foregroundColor(.primary.opacity(0.6))
            }

            Text(entry.date ?? Date(), style: .date)
                .font(.pingFangLight(size: 14))
                .foregroundColor(.secondary)

            Text(entry.text ?? "")
                .font(.pingFangRegular(size: 15))
                .lineLimit(3)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading) // 👈 force full width
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}


// Original view now uses the simplified version
struct JournalListView: View {
    var body: some View {
        SimpleJournalListView()
    }
}
