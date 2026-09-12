import Foundation

struct HydrationEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let amountML: Int

    init(amountML: Int, date: Date = .now) {
        self.id = UUID()
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
        colorName = try container.decodeIfPresent(String.self, forKey: .colorName) ?? "blue"
    }
}
