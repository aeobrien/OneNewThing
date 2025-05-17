// ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var assignmentManager: AssignmentManager
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView {
            // HOME TAB
            NavigationView {
                SimpleHomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }
            
            // ACTIVITIES TAB
            NavigationView {
                SimpleActivitiesView()
                    .navigationTitle("Activities")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Activities", systemImage: "list.bullet") }
            
            // JOURNAL TAB
            NavigationView {
                SimpleJournalListView()
                    .navigationTitle("Journal")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Journal", systemImage: "book") }
            
            // SETTINGS TAB
            NavigationView {
                SimpleSettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(assignmentManager)
        .environment(\.managedObjectContext, viewContext)
        .onAppear {
            print("📱 TabView appeared with manager: \(type(of: assignmentManager))")
        }
    }
}
