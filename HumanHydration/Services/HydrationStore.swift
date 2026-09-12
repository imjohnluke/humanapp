import Foundation

final class HydrationStore: ObservableObject {
    @Published var dailyGoalML: Int { didSet { save() } }
    @Published private(set) var entries: [HydrationEntry] { didSet { save() } }
    @Published var bottle: WaterBottle? { didSet { save() } }

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    init() {
        dailyGoalML = defaults.object(forKey: "dailyGoalML") as? Int ?? 2400
        entries = (try? JSONDecoder().decode([HydrationEntry].self, from: defaults.data(forKey: "entries") ?? Data())) ?? []
        bottle = (try? JSONDecoder().decode(WaterBottle.self, from: defaults.data(forKey: "bottle") ?? Data()))
    }

    var todayAmountML: Int {
        entries.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.amountML }
    }

    var todayProgress: Double { min(Double(todayAmountML) / Double(max(dailyGoalML, 1)), 1) }

    func addWater(_ amountML: Int) { entries.append(HydrationEntry(amountML: amountML)) }

    func removeEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func amount(on date: Date) -> Int {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amountML }
    }

    private func save() {
        defaults.set(dailyGoalML, forKey: "dailyGoalML")
        defaults.set(try? JSONEncoder().encode(entries), forKey: "entries")
        if let bottle, let data = try? JSONEncoder().encode(bottle) {
            defaults.set(data, forKey: "bottle")
        } else {
            defaults.removeObject(forKey: "bottle")
        }
    }
}
