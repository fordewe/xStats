import SwiftUI

struct SensorsPanelView: View {
    @EnvironmentObject var collector: StatsCollector

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accentYellow)
                
                Text("Sensors")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
            }

            // Battery Section
            if let battery = collector.currentStats.battery {
                BatterySectionView(battery: battery)
            }

            Divider().background(Theme.divider)

            // Temperature Section
            if let temperature = collector.currentStats.temperature {
                TemperatureSectionView(temperature: temperature)
            }

            Divider().background(Theme.divider)

            // Fan Section
            if let fan = collector.currentStats.fan {
                FanSectionView(fan: fan)
            }

            Spacer()
        }
        .padding(Theme.cardPadding)
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .background(Theme.panelBackground)
    }
}

// MARK: - Battery Section
struct BatterySectionView: View {
    let battery: BatteryStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Battery header with icon
            HStack(spacing: 6) {
                Image(systemName: batteryIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(batteryColor)
                
                Text("Battery")
                    .font(Theme.labelFont)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                // Charging indicator
                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.accentYellow)
                }
            }
            
            // Battery level with visual bar
            HStack(spacing: 10) {
                // Battery percentage
                Text("\(battery.level)%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                // Battery bar
                BatteryBarView(level: battery.level, isCharging: battery.isCharging)
            }
            
            // Additional info
            HStack(spacing: 12) {
                // Time remaining
                if let time = battery.timeRemaining, time > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textTertiary)
                        Text(time.formattedTime())
                            .font(Theme.smallFont)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Cycle count
                HStack(spacing: 4) {
                    Text("Cycles:")
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.textTertiary)
                    Text("\(battery.cycleCount)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    private var batteryIcon: String {
        if battery.isCharging {
            return "battery.100percent.bolt"
        }
        switch battery.level {
        case 76...100: return "battery.100percent"
        case 51...75: return "battery.75percent"
        case 26...50: return "battery.50percent"
        case 1...25: return "battery.25percent"
        default: return "battery.0percent"
        }
    }
    
    private var batteryColor: Color {
        if battery.isCharging { return Theme.accentGreen }
        if battery.level <= 20 { return Theme.accentRed }
        if battery.level <= 40 { return Theme.accentOrange }
        return Theme.accentGreen
    }
}

// Battery Bar View
struct BatteryBarView: View {
    let level: Int
    let isCharging: Bool
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Battery outline
            RoundedRectangle(cornerRadius: 3)
                .stroke(Theme.textTertiary, lineWidth: 1)
                .frame(width: 50, height: 20)
            
            // Battery fill
            RoundedRectangle(cornerRadius: 2)
                .fill(batteryFillColor)
                .frame(width: CGFloat(level) / 100 * 46, height: 16)
                .padding(.leading, 2)
            
            // Battery tip
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.textTertiary)
                .frame(width: 3, height: 8)
                .offset(x: 52)
        }
        .frame(width: 55, height: 20)
    }
    
    private var batteryFillColor: Color {
        if isCharging { return Theme.accentGreen }
        if level <= 20 { return Theme.accentRed }
        if level <= 40 { return Theme.accentOrange }
        return Theme.accentGreen
    }
}

// MARK: - Temperature Section
struct TemperatureSectionView: View {
    let temperature: TemperatureStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accentOrange)
                
                Text("Temperature")
                    .font(Theme.labelFont)
                    .foregroundColor(Theme.textSecondary)
            }
            
            VStack(spacing: 6) {
                // CPU Temperature
                if let cpu = temperature.cpu {
                    SensorTemperatureRow(label: "CPU", value: cpu)
                }

                // GPU Temperature
                if let gpu = temperature.gpu {
                    SensorTemperatureRow(label: "GPU", value: gpu)
                }

                // Memory Temperature
                if let memory = temperature.memory {
                    SensorTemperatureRow(label: "Memory", value: memory)
                }

                // Battery Temperature
                if let battery = temperature.battery {
                    SensorTemperatureRow(label: "Battery", value: battery)
                }
            }
        }
    }
}

struct SensorTemperatureRow: View {
    let label: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.detailFont)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
            
            Text("\(Int(value))°C")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(tempColor)
        }
    }
    
    private var tempColor: Color {
        if value > 90 { return Theme.accentRed }
        if value > 70 { return Theme.accentOrange }
        if value > 50 { return Theme.accentYellow }
        return Theme.accentGreen
    }
}

// MARK: - Fan Section
struct FanSectionView: View {
    let fan: FanStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "fan")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accentCyan)
                
                Text("Fans")
                    .font(Theme.labelFont)
                    .foregroundColor(Theme.textSecondary)
            }
            
            ForEach(0..<min(fan.count, fan.speeds.count), id: \.self) { index in
                // Only show fans that have non-zero speeds
                if fan.speeds[index] > 0 {
                    HStack {
                        Text("Fan \(index + 1)")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)

                        Spacer()

                        Text("\(fan.speeds[index]) RPM")
                            .font(Theme.smallFont)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
    }
}

#Preview {
    SensorsPanelView()
        .environmentObject(StatsCollector.shared)
        .frame(width: 220, height: 360)
        .padding()
        .background(Theme.background)
}
