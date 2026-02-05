import SwiftUI

struct SensorsView: View {
    let stats: SystemStats

    var body: some View {
        VStack(spacing: Theme.cardSpacing) {
            if let battery = stats.battery {
                BatteryCard(battery: battery)
            }

            if let temperature = stats.temperature {
                TemperatureCard(temperature: temperature)
            }

            if let fan = stats.fan {
                FanCard(fan: fan)
            }
        }
    }
}

struct BatteryCard: View {
    let battery: BatteryStats

    var body: some View {
        StatCard(icon: batteryIcon, title: "Battery", color: batteryColor) {
            HStack(spacing: 16) {
                CircularProgress(
                    percentage: Double(battery.level) / 100,
                    color: batteryColor
                )
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(battery.level)%")
                        .font(Theme.valueFont)
                        .foregroundColor(Theme.textPrimary)

                    if battery.isCharging {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(Theme.accentGreen)
                            Text("Charging")
                                .font(Theme.labelFont)
                                .foregroundColor(Theme.textSecondary)
                        }
                    } else if battery.isPlugged {
                        Text("Plugged in")
                            .font(Theme.labelFont)
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        if let time = battery.timeRemaining {
                            Text("\(time.formattedTime()) remaining")
                                .font(Theme.labelFont)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    HStack {
                        Text("Health: \(battery.health)%")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)

                        Text("•")
                            .foregroundColor(Theme.textSecondary)

                        Text("Cycles: \(battery.cycleCount)")
                            .font(Theme.detailFont)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()
            }
        }
    }

    private var batteryIcon: String {
        if battery.isCharging {
            return "battery.100.bolt"
        }
        let level = battery.level
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        if battery.isCharging {
            return Theme.accentGreen
        }
        let level = battery.level
        if level > 50 { return Theme.accentGreen }
        if level > 20 { return Theme.accentYellow }
        return Theme.accentRed
    }
}

struct TemperatureCard: View {
    let temperature: TemperatureStats

    var body: some View {
        StatCard(icon: "thermometer", title: "Temperature", color: temperatureColor(temperature.cpu ?? 0)) {
            VStack(spacing: 8) {
                if let cpu = temperature.cpu {
                    TemperatureRow(label: "CPU", value: cpu)
                }

                if let gpu = temperature.gpu {
                    TemperatureRow(label: "GPU", value: gpu)
                }

                if let memory = temperature.memory {
                    TemperatureRow(label: "Memory", value: memory)
                }

                if let battery = temperature.battery {
                    TemperatureRow(label: "Battery", value: battery)
                }
            }
        }
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp > 80 {
            return Theme.accentRed
        } else if temp > 60 {
            return Theme.accentYellow
        } else {
            return Theme.accentBlue
        }
    }
}

struct TemperatureRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.labelFont)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text("\(Int(value))°C")
                .font(Theme.labelFont)
                .foregroundColor(colorForTemp(value))
        }
    }

    private func colorForTemp(_ temp: Double) -> Color {
        if temp > 80 {
            return Theme.accentRed
        } else if temp > 60 {
            return Theme.accentYellow
        } else {
            return Theme.textPrimary
        }
    }
}

struct FanCard: View {
    let fan: FanStats

    var body: some View {
        StatCard(icon: "fan", title: "Fan", color: Theme.accentBlue) {
            VStack(spacing: 8) {
                ForEach(0..<fan.count, id: \.self) { index in
                    let speed = index < fan.speeds.count ? fan.speeds[index] : 0
                    FanRow(index: index, speed: speed)
                }
            }
        }
    }
}

struct FanRow: View {
    let index: Int
    let speed: Int

    var body: some View {
        HStack {
            Text("Fan \(index + 1)")
                .font(Theme.labelFont)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text("\(speed) RPM")
                .font(Theme.labelFont)
                .foregroundColor(Theme.textPrimary)

            // Visual indicator
            Circle()
                .fill(colorForSpeed(speed))
                .frame(width: 6, height: 6)
        }
    }

    private func colorForSpeed(_ speed: Int) -> Color {
        if speed > 5000 {
            return Theme.accentRed
        } else if speed > 3000 {
            return Theme.accentYellow
        } else {
            return Theme.accentGreen
        }
    }
}
