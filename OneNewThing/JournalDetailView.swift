/// JournalDetailView.swift
import SwiftUI
import CoreData

struct JournalDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var entry: JournalEntry
    @State private var showEditView = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Activity name and date
                    VStack(alignment: .leading, spacing: 8) {
                        if let activityName = entry.title, !activityName.isEmpty {
                            Text(activityName)
                                .font(.pingFangSemibold(size: 24))
                                .foregroundColor(.primary)
                        } else {
                            Text("Untitled Activity")
                                .font(.pingFangSemibold(size: 24))
                                .foregroundColor(.primary.opacity(0.6))
                        }
                        
                        Text(entry.date ?? Date(), style: .date)
                            .font(.pingFangLight(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Divider()
                    
                    // Journal content
                    Text(entry.text ?? "")
                        .font(.pingFangRegular(size: 16))
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showEditView = true
                    }
                    .font(.pingFangMedium(size: 16))
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.pingFangMedium(size: 16))
                }
            }
            .sheet(isPresented: $showEditView) {
                NavigationStack {
                    EditJournalView(entry: entry)
                }
            }
        }
    }
}