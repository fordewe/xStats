import SwiftUI

struct UserSystemCircularChart: View {
    let userUsage: Double
    let systemUsage: Double

    private let thickness: CGFloat = 6
    private let size: CGFloat = 70

    var body: some View {
        ZStack {
            // Background circle with subtle glow
            Circle()
                .stroke(Theme.background.opacity(0.5), lineWidth: thickness)
            
            // Track circle
            Circle()
                .stroke(Theme.cardBackground, lineWidth: thickness)

            // System portion (red/orange) - starts from bottom
            Circle()
                .trim(from: 0, to: systemPercentage / 100)
                .stroke(
                    AngularGradient(
                        colors: [Theme.accentRed, Theme.accentOrange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accentRed.opacity(0.4), radius: 3, x: 0, y: 0)

            // User portion (blue/cyan) - continues after system
            Circle()
                .trim(from: systemPercentage / 100, to: totalPercentage / 100)
                .stroke(
                    AngularGradient(
                        colors: [Theme.accentBlue, Theme.accentCyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accentBlue.opacity(0.4), radius: 3, x: 0, y: 0)
            
            // Center content
            VStack(spacing: 1) {
                Text("\(Int(totalPercentage))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text("%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }

    private var systemPercentage: Double {
        min(systemUsage, 100)
    }

    private var totalPercentage: Double {
        min(userUsage + systemUsage, 100)
    }
}

#Preview {
    VStack(spacing: 20) {
        UserSystemCircularChart(userUsage: 35, systemUsage: 15)
        UserSystemCircularChart(userUsage: 60, systemUsage: 20)
        UserSystemCircularChart(userUsage: 10, systemUsage: 5)
    }
    .padding()
    .background(Theme.background)
}
