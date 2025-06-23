// ContentView.swift
import SwiftUI

// Create a custom font extension to easily use PingFang SC throughout the app
extension Font {
    static func pingFangRegular(size: CGFloat) -> Font {
        return .custom("PingFangSC-Regular", size: size)
    }
    
    static func pingFangMedium(size: CGFloat) -> Font {
        return .custom("PingFangSC-Medium", size: size)
    }
    
    static func pingFangSemibold(size: CGFloat) -> Font {
        return .custom("PingFangSC-Semibold", size: size)
    }
    
    static func pingFangLight(size: CGFloat) -> Font {
        return .custom("PingFangSC-Light", size: size)
    }
}

struct ContentView: View {
    @EnvironmentObject var assignmentManager: AssignmentManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        TabView {
            // HOME TAB
            NavigationView {
                SimpleHomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
                    .font(.pingFangRegular(size: 12))
            }
            
            // ACTIVITIES TAB
            NavigationView {
                ActivitiesView()
            }
            .tabItem {
                Label("Activities", systemImage: "list.bullet")
                    .font(.pingFangRegular(size: 12))
            }
            
            // JOURNAL TAB
            NavigationView {
                SimpleJournalListView()
                    .navigationTitle("Journal")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Journal", systemImage: "book.fill")
                    .font(.pingFangRegular(size: 12))
            }
            
            // SETTINGS TAB
            NavigationView {
                SimpleSettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
                    .font(.pingFangRegular(size: 12))
            }
        }
        .environmentObject(assignmentManager)
        .environment(\.managedObjectContext, viewContext)
        .accentColor(Color("AccentColor"))
        .onAppear {
            // Apply UI customization to the tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            
            // Set background color
            appearance.backgroundColor = colorScheme == .dark ? 
                                        UIColor(white: 0.1, alpha: 0.95) : 
                                        UIColor(white: 0.97, alpha: 0.95)
            
            // Remove separator line
            appearance.shadowColor = .clear
            
            // Apply rounded corners and subtle shadow
            UITabBar.appearance().layer.cornerRadius = 20
            UITabBar.appearance().layer.masksToBounds = true
            UITabBar.appearance().layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            
            // Apply the appearance
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
            print("📱 TabView appeared with manager: \(type(of: assignmentManager))")
        }
    }
}
