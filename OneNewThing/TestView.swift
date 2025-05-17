import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color.purple.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("TEST VIEW")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("If you can see this, rendering is working!")
                    .foregroundColor(.white)
                    .font(.headline)
                
                Button(action: {
                    print("Button tapped")
                }) {
                    Text("Tap Me")
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .onAppear {
            print("🟣 TestView appeared")
        }
    }
}

// Preview provider for SwiftUI canvas
struct TestView_Previews: PreviewProvider {
    static var previews: some View {
        TestView()
    }
} 