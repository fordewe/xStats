import SwiftUI

struct Theme {
    // Colors - Modern dark theme inspired by iStat Menus
    static let background = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let panelBackground = Color(red: 0.10, green: 0.10, blue: 0.12)
    
    // Accent colors - vibrant and modern
    static let accentBlue = Color(red: 0.20, green: 0.60, blue: 1.0)
    static let accentCyan = Color(red: 0.30, green: 0.85, blue: 0.95)
    static let accentGreen = Color(red: 0.30, green: 0.85, blue: 0.45)
    static let accentYellow = Color(red: 1.0, green: 0.80, blue: 0.20)
    static let accentOrange = Color(red: 1.0, green: 0.55, blue: 0.20)
    static let accentRed = Color(red: 1.0, green: 0.35, blue: 0.35)
    static let accentPurple = Color(red: 0.70, green: 0.40, blue: 0.95)
    static let accentPink = Color(red: 1.0, green: 0.40, blue: 0.60)
    
    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.65, green: 0.65, blue: 0.70)
    static let textTertiary = Color(red: 0.45, green: 0.45, blue: 0.50)
    
    // Divider
    static let divider = Color.white.opacity(0.08)

    // Gradients - more vibrant
    static let graphGradient = LinearGradient(
        colors: [accentCyan, accentBlue],
        startPoint: .top,
        endPoint: .bottom
    )

    static let areaGradient = LinearGradient(
        colors: [accentBlue.opacity(0.5), accentBlue.opacity(0.05)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cpuGradient = LinearGradient(
        colors: [accentCyan.opacity(0.6), accentBlue.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let memoryGradient = LinearGradient(
        colors: [accentPurple.opacity(0.6), accentPurple.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let networkUpGradient = LinearGradient(
        colors: [accentOrange.opacity(0.6), accentOrange.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let networkDownGradient = LinearGradient(
        colors: [accentGreen.opacity(0.6), accentGreen.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let diskReadGradient = LinearGradient(
        colors: [accentCyan.opacity(0.6), accentCyan.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let diskWriteGradient = LinearGradient(
        colors: [accentPink.opacity(0.6), accentPink.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )

    // Spacing
    static let cardPadding: CGFloat = 14
    static let cardSpacing: CGFloat = 10
    static let panelSpacing: CGFloat = 8

    // Corner radius
    static let cardRadius: CGFloat = 10
    static let smallRadius: CGFloat = 6

    // Typography
    static let titleFont = Font.system(size: 13, weight: .semibold)
    static let subtitleFont = Font.system(size: 11, weight: .medium)
    static let valueFont = Font.system(size: 22, weight: .bold, design: .rounded)
    static let valueLargeFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let labelFont = Font.system(size: 11, weight: .medium)
    static let detailFont = Font.system(size: 10, weight: .regular)
    static let smallFont = Font.system(size: 9, weight: .regular)
    
    // Panel dimensions
    static let panelWidth: CGFloat = 200
    static let panelHeight: CGFloat = 340
}
