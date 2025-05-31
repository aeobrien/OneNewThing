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
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(PlainListStyle())
            }
        }
        .onAppear {
            // Apply custom list style
            UITableView.appearance().backgroundColor = UIColor.clear
            UITableView.appearance().separatorStyle = .none
            
            print("📔 SimpleJournalListView appeared with \(entries.count) entries")
        }
    }
}

struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.title ?? "Untitled")
                    .font(.pingFangSemibold(size: 18))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(entry.date ?? Date(), style: .date)
                    .font(.pingFangLight(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Text(entry.text ?? "")
                .font(.pingFangRegular(size: 15))
                .lineLimit(2)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
        }
        .padding(16)
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
