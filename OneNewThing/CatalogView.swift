/// CatalogView.swift
import SwiftUI
import CoreData

struct ActivityRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    let activity: Activity
    var onEdit: (Activity) -> Void
    @State private var showDeleteConfirm = false
    @State private var showActions = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(isOn: Binding(
                    get: { activity.isIncluded },
                    set: { newValue in
                        activity.isIncluded = newValue
                        try? viewContext.save()
                    }
                )) {
                    Text(activity.name ?? "")
                        .font(.pingFangRegular(size: 16))
                }
                .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                
                Spacer()
                
                // Edit/Delete buttons that appear when tapped
                if showActions {
                    HStack(spacing: 12) {
                        Button {
                            onEdit(activity)
                            showActions = false
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundColor(Color("AccentColor"))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color("AccentColor").opacity(0.1))
                                )
                        }
                        
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .padding(.leading, 8)
                } else {
                    Button {
                        withAnimation {
                            showActions = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(Color(.systemBackground))
            .alert("Delete Activity", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {
                    // No action needed
                }
                Button("Delete", role: .destructive) {
                    withAnimation {
                        viewContext.delete(activity)
                        try? viewContext.save()
                        showActions = false
                    }
                }
            } message: {
                Text("Are you sure you want to delete this activity?")
            }
            .onTapGesture {
                // Allow tapping anywhere on the row to toggle action buttons
                withAnimation {
                    showActions.toggle()
                }
            }
            
            Divider()
                .padding(.leading)
        }
    }
}

struct CatalogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ExperienceCategory.name, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<ExperienceCategory>

    @State private var selectedActivityForEdit: Activity?
    // Flag for showing add activity sheet
    @State private var showingAdd = false

    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar to eliminate spacing issues
            HStack {
                Text("Activity Catalog")
                    .font(.pingFangSemibold(size: 17))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.systemGray4)),
                alignment: .bottom
            )
            
            // Custom scrollable content without List overhead
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(categories) { category in
                        // Category header
                        HStack {
                            Text(category.name ?? "")
                                .font(.pingFangMedium(size: 16))
                                .foregroundColor(.primary.opacity(0.8))
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                            Spacer()
                        }
                        .background(Color(.systemGray6).opacity(0.5))
                        
                        // Activities in this category
                        ForEach(category.activitiesArray, id: \.objectID) { activity in
                            ActivityRow(activity: activity) { act in
                                selectedActivityForEdit = act
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                AddNewActivityView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(item: $selectedActivityForEdit) { activity in
            NavigationStack {
                EditActivityView(activity: activity)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .accentColor(Color("AccentColor"))
    }
}

