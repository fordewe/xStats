import SwiftUI

struct GradientGraph: View {
    let data: [Double]
    let color: Color
    private let lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let points = normalizeData(data: data, size: geometry.size)

            ZStack {
                // Fill area
                Path { path in
                    guard !points.isEmpty else { return }

                    path.move(to: CGPoint(x: points[0].x, y: geometry.size.height))

                    for point in points {
                        path.addLine(to: CGPoint(x: point.x, y: point.y))
                    }

                    path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.5), color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    guard !points.isEmpty else { return }

                    path.move(to: points[0])

                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalizeData(data: [Double], size: CGSize) -> [CGPoint] {
        guard !data.isEmpty else { return [] }

        let maxVal = data.max() ?? 100
        let minVal = data.min() ?? 0
        let range = maxVal - minVal

        let xStep = size.width / CGFloat(max(data.count - 1, 1))

        return data.enumerated().map { index, value in
            let x = CGFloat(index) * xStep
            let normalizedValue = range > 0 ? (value - minVal) / range : 0.5
            let y = size.height - (CGFloat(normalizedValue) * size.height * 0.8) - (size.height * 0.1)
            return CGPoint(x: x, y: y)
        }
    }
}
