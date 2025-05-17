/// LongPressButton.swift
import SwiftUI

struct LongPressButton<Label: View>: View {
    let duration: TimeInterval
    let action: () -> Void
    let label: () -> Label
    @GestureState private var progress: Double = 0

    var body: some View {
        label()
            .overlay(
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: geo.size.width * CGFloat(progress))
                        .animation(.linear, value: progress)
                }
            )
            .gesture(
                LongPressGesture(minimumDuration: duration)
                    .updating($progress) { value, state, _ in state = value ? 1 : 0 }
                    .onEnded { _ in action() }
            )
    }
}
