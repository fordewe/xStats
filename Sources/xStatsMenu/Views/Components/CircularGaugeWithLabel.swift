import SwiftUI

struct CircularGaugeWithLabel: View {
    let value: Double
    let label: String
    let color: Color
    let bottomText: String?

    private let thickness: CGFloat = 6
    private let size: CGFloat = 65

    init(value: Double, label: String, color: Color, bottomText: String? = nil) {
        self.value = value
        self.label = label
        self.color = color
        self.bottomText = bottomText
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle with shadow
                Circle()
                    .stroke(Theme.background.opacity(0.5), lineWidth: thickness)

                // Value circle with gradient
                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(
                        AngularGradient(
                            colors: [color, color.opacity(0.7)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 0)

                // Center label
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(width: size, height: size)

            if let bottomText = bottomText {
                Text(bottomText)
                    .font(Theme.smallFont)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var percentage: Double {
        min(max(value, 0), 100)
    }
}

#Preview {
    HStack(spacing: 16) {
        CircularGaugeWithLabel(value: 75, label: "75%", color: Theme.accentBlue, bottomText: "Usage")
        CircularGaugeWithLabel(value: 45, label: "45%", color: Theme.accentGreen, bottomText: "Free")
        CircularGaugeWithLabel(value: 90, label: "90%", color: Theme.accentRed, bottomText: "Pressure")
    }
    .padding()
    .background(Theme.cardBackground)
}
