import SwiftUI

struct CircularProgress: View {
    let percentage: Double
    let color: Color

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    Theme.cardBackground,
                    lineWidth: 6
                )

            // Progress circle
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.3), value: percentage)
        }
    }
}
