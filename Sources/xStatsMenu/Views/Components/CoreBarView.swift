import SwiftUI

struct CoreBarView: View {
    let label: String
    let usage: Double
    let color: Color

    private let barHeight: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(Theme.detailFont)
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Text("\(Int(usage))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(barColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.background)

                    // Fill with gradient
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [barColor, barColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (usage / 100))
                        .shadow(color: barColor.opacity(0.3), radius: 2, x: 0, y: 0)
                }
            }
            .frame(height: barHeight)
        }
    }
    
    private var barColor: Color {
        if usage > 80 { return Theme.accentRed }
        if usage > 60 { return Theme.accentOrange }
        return color
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        CoreBarView(label: "Efficiency", usage: 35, color: Theme.accentGreen)
        CoreBarView(label: "Performance", usage: 65, color: Theme.accentPurple)
        CoreBarView(label: "Combined", usage: 85, color: Theme.accentBlue)
    }
    .padding()
    .frame(width: 180)
    .background(Theme.cardBackground)
}
