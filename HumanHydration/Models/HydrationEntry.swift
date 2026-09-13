import Foundation

struct HydrationEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let amountML: Int

    init(amountML: Int, date: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.date = date
        self.amountML = amountML
    }
}

/// Goal comparisons use the current tracking goal, not a historical medical target.
struct HydrationStatistics {
    let entries: [HydrationEntry]
    let goalML: Int
    var now = Date.now
    var calendar = Calendar.current

    var dailyTotals: [Date: Int] {
        entries.reduce(into: [:]) { result, entry in
            guard entry.date <= now, entry.amountML > 0 else { return }
            result[calendar.startOfDay(for: entry.date), default: 0] += entry.amountML
        }
    }
    var week: [(date: Date, amount: Int)] {
        let totals = dailyTotals
        return (-6...0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
            return (date, totals[date, default: 0])
        }
    }
    var dailyAverageML: Int { week.reduce(0) { $0 + $1.amount } / 7 }
    struct HourlyIntake: Identifiable {
        let hour: Int
        let todayML: Int
        let yesterdayML: Int
        var id: Int { hour }
    }

    var hourlyIntake: [HourlyIntake] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        var todayTotals = Array(repeating: 0, count: 24)
        var yesterdayTotals = Array(repeating: 0, count: 24)
        for entry in entries where entry.amountML > 0 && entry.date <= now {
            let hour = calendar.component(.hour, from: entry.date)
            if calendar.isDate(entry.date, inSameDayAs: today) {
                todayTotals[hour] += entry.amountML
            } else if calendar.isDate(entry.date, inSameDayAs: yesterday) {
                yesterdayTotals[hour] += entry.amountML
            }
        }
        return (0..<24).map { HourlyIntake(hour: $0, todayML: todayTotals[$0], yesterdayML: yesterdayTotals[$0]) }
    }

    var yesterdayAmountByNow: Int {
        let cutoff = calendar.date(byAdding: .day, value: -1, to: now)!
        return entries.filter {
            $0.amountML > 0 && $0.date <= cutoff && calendar.isDate($0.date, inSameDayAs: cutoff)
        }.reduce(0) { $0 + $1.amountML }
    }

    var comparisonInsight: String {
        let todayAmount = hourlyIntake.reduce(0) { $0 + $1.todayML }
        let yesterdayAmount = yesterdayAmountByNow
        guard yesterdayAmount > 0 else {
            return "No water was logged by this time yesterday. Keep logging to discover your daily patterns."
        }
        let difference = todayAmount - yesterdayAmount
        if difference == 0 {
            return "You’ve logged \(WaterVolume.label(todayAmount))—the same amount as by this time yesterday."
        }
        return "You’ve logged \(WaterVolume.label(abs(difference))) \(difference > 0 ? "more" : "less") than by this time yesterday (\(WaterVolume.label(todayAmount)) today vs \(WaterVolume.label(yesterdayAmount)) yesterday)."
    }

    var habitInsight: String {
        let hours = hourlyIntake
        let todayAmount = hours.reduce(0) { $0 + $1.todayML }
        if goalML > 0 && todayAmount >= goalML {
            return "You’ve reached today’s target. Extra water won’t add another streak day."
        }
        if let peak = hours.filter({ $0.yesterdayML > 0 }).max(by: { $0.yesterdayML < $1.yesterdayML }) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let time = calendar.date(bySettingHour: peak.hour, minute: 0, second: 0, of: yesterday)!
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("j")
            return "Your busiest logging hour yesterday was \(formatter.string(from: time)), with \(WaterVolume.label(peak.yesterdayML)). Try pairing a logging reminder with a regular part of your day."
        }
        return "Log water when you drink it so your hourly chart reflects your routine. A reminder alongside a meal can help you remember to log."
    }

    var bestStreak: Int {
        guard goalML > 0 else { return 0 }
        let completedDays = dailyTotals.filter { $0.value >= goalML }.keys.sorted()
        var previousDay: Date?
        var run = 0
        var best = 0
        for day in completedDays {
            if let previousDay,
               calendar.date(byAdding: .day, value: 1, to: previousDay) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previousDay = day
        }
        return best
    }

    var currentStreak: Int {
        guard goalML > 0 else { return 0 }
        let totals = dailyTotals
        var day = calendar.startOfDay(for: now)
        if totals[day, default: 0] < goalML {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while totals[day, default: 0] >= goalML {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}

struct WaterBottle: Identifiable, Codable {
    let id: UUID
    var name: String
    var capacityML: Int
    var assetName: String
    var colorName: String

    init(name: String = "Smartwater", capacityML: Int = 1000, assetName: String = "bottle", colorName: String = "clear") {
        self.id = UUID()
        self.name = name
        self.capacityML = capacityML
        self.assetName = assetName
        self.colorName = colorName
    }

    enum CodingKeys: String, CodingKey { case id, name, capacityML, assetName, colorName }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "My bottle"
        capacityML = try container.decodeIfPresent(Int.self, forKey: .capacityML) ?? 750
        assetName = try container.decodeIfPresent(String.self, forKey: .assetName) ?? "bottle"
        colorName = try container.decodeIfPresent(String.self, forKey: .colorName) ?? "clear"
    }
}

struct SavedDrink: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var capacityML: Int
    var isEstimate: Bool

    func amount(quarters: Int) -> Int {
        max(10, Int((Double(capacityML) * Double(min(max(quarters, 1), 4)) / 4).rounded()))
    }
}
