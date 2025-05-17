// ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // HOME TAB
            NavigationStack {
                HomeView()
                    .navigationTitle("Home")
                    .onAppear { print("📱 HomeView appeared") }
            }
            .tabItem { Label("Home", systemImage: "house") }

            // ACTIVITIES TAB
            NavigationStack {
                ActivitiesView()
                    .navigationTitle("My Activities")
                    .onAppear { print("📋 ActivitiesView appeared") }
            }
            .tabItem { Label("Activities", systemImage: "checkmark.circle") }

            // JOURNAL TAB
            NavigationStack {
                JournalListView()
                    .navigationTitle("Journal")
                    .onAppear { print("📔 JournalListView appeared") }
            }
            .tabItem { Label("Journal", systemImage: "book") }

            // SETTINGS TAB
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .onAppear { print("⚙️ SettingsView appeared") }
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
