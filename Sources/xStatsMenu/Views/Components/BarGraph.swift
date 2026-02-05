import SwiftUI

struct BarGraph: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(data.indices, id: \.self) { index in
                    Bar(value: data[index], color: color, geometry: geometry, count: data.count)
                }
            }
        }
    }
}

struct Bar: View {
    let value: Double
    let color: Color
    let geometry: GeometryProxy
    let count: Int

    var body: some View {
        let barWidth: CGFloat = (geometry.size.width - CGFloat(count - 1) * 2) / CGFloat(count)
        let barHeight: CGFloat = CGFloat(value) / 100 * geometry.size.height

        return RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: barWidth, height: barHeight)
    }

    private var barColor: Color {
        if value > 80 {
            return Theme.accentRed
        } else if value > 60 {
            return Theme.accentYellow
        } else {
            return color
        }
    }
}
