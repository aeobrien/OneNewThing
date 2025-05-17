import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notifications")) {
                    Text("Daily reminder at 9:00 AM")
                        .foregroundColor(.secondary)
                }
                Section(header: Text("Assignments")) {
                    Text("New task every 7 days")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
