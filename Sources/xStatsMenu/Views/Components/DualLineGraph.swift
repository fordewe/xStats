import SwiftUI

struct DualLineGraph: View {
    let primaryValues: [Double]
    let secondaryValues: [Double]
    let primaryColor: Color
    let secondaryColor: Color
    var showFill: Bool = true
    var showLegend: Bool = false
    var primaryLabel: String = ""
    var secondaryLabel: String = ""

    private let maxHeight: CGFloat = 60

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let allValues = primaryValues + secondaryValues
                let maxVal = max(allValues.max() ?? 1, 1)

                ZStack {
                    // Grid lines (subtle)
                    VStack(spacing: 0) {
                        ForEach(0..<3) { _ in
                            Spacer()
                            Rectangle()
                                .fill(Theme.divider)
                                .frame(height: 0.5)
                        }
                        Spacer()
                    }
                    
                    // Primary fill area
                    if showFill {
                        primaryFillPath(width: width, height: height, maxVal: maxVal)
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor.opacity(0.4), primaryColor.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    // Primary line
                    primaryLinePath(width: width, height: height, maxVal: maxVal)
                        .stroke(
                            LinearGradient(
                                colors: [primaryColor, primaryColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                        )
                    
                    // Secondary fill area
                    if showFill {
                        secondaryFillPath(width: width, height: height, maxVal: maxVal)
                            .fill(
                                LinearGradient(
                                    colors: [secondaryColor.opacity(0.3), secondaryColor.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    // Secondary line
                    secondaryLinePath(width: width, height: height, maxVal: maxVal)
                        .stroke(
                            LinearGradient(
                                colors: [secondaryColor, secondaryColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                        )
                }
            }
            .frame(height: maxHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius))
            .background(
                RoundedRectangle(cornerRadius: Theme.smallRadius)
                    .fill(Theme.background.opacity(0.3))
            )
            
            // Legend
            if showLegend {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(primaryColor).frame(width: 6, height: 6)
                        Text(primaryLabel).font(Theme.smallFont).foregroundColor(Theme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(secondaryColor).frame(width: 6, height: 6)
                        Text(secondaryLabel).font(Theme.smallFont).foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    private func primaryLinePath(width: CGFloat, height: CGFloat, maxVal: Double) -> Path {
        Path { path in
            guard !primaryValues.isEmpty else { return }
            let stepX = width / CGFloat(max(primaryValues.count - 1, 1))
            
            for (index, value) in primaryValues.enumerated() {
                let x = CGFloat(index) * stepX
                let y = height - (CGFloat(value) / CGFloat(maxVal) * height)
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
    
    private func secondaryLinePath(width: CGFloat, height: CGFloat, maxVal: Double) -> Path {
        Path { path in
            guard !secondaryValues.isEmpty else { return }
            let stepX = width / CGFloat(max(secondaryValues.count - 1, 1))
            
            for (index, value) in secondaryValues.enumerated() {
                let x = CGFloat(index) * stepX
                let y = height - (CGFloat(value) / CGFloat(maxVal) * height)
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
    
    private func primaryFillPath(width: CGFloat, height: CGFloat, maxVal: Double) -> Path {
        Path { path in
            guard !primaryValues.isEmpty else { return }
            let stepX = width / CGFloat(max(primaryValues.count - 1, 1))
            
            path.move(to: CGPoint(x: 0, y: height))
            
            for (index, value) in primaryValues.enumerated() {
                let x = CGFloat(index) * stepX
                let y = height - (CGFloat(value) / CGFloat(maxVal) * height)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }
    
    private func secondaryFillPath(width: CGFloat, height: CGFloat, maxVal: Double) -> Path {
        Path { path in
            guard !secondaryValues.isEmpty else { return }
            let stepX = width / CGFloat(max(secondaryValues.count - 1, 1))
            
            path.move(to: CGPoint(x: 0, y: height))
            
            for (index, value) in secondaryValues.enumerated() {
                let x = CGFloat(index) * stepX
                let y = height - (CGFloat(value) / CGFloat(maxVal) * height)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }
}

#Preview {
    VStack {
        DualLineGraph(
            primaryValues: [10, 25, 30, 20, 40, 35, 50],
            secondaryValues: [5, 15, 10, 25, 20, 30, 25],
            primaryColor: Theme.accentBlue,
            secondaryColor: Theme.accentGreen,
            showLegend: true,
            primaryLabel: "Upload",
            secondaryLabel: "Download"
        )
        .frame(width: 170)

        Text("Upload / Download")
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
    }
    .padding()
    .background(Theme.cardBackground)
}
