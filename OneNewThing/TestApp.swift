import SwiftUI

// Note: Only one App can have @main - comment this out if using the regular app
// @main
struct TestApp: App {
    init() {
        print("🧪 TestApp initializing")
    }
    
    var body: some Scene {
        print("🧪 TestApp building scene")
        return WindowGroup {
            ZStack {
                Color.orange.ignoresSafeArea()
                VStack {
                    Text("TEST APP")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    Text("Alternative Entry Point")
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                print("🧪 TestApp view appeared")
            }
        }
    }
} 