import Foundation
import Combine

final class HydrationStore: ObservableObject {
    @Published var displayName: String { didSet { save() } }
    @Published var dailyGoalML: Int { didSet { save() } }
    @Published private(set) var entries: [HydrationEntry] { didSet { save() } }
    @Published var bottle: WaterBottle? { didSet { save() } }

    private let defaults: UserDefaults
    private let accountID: String?
    private let calendar = Calendar.current

    init(defaults: UserDefaults = .standard, accountID: String? = nil) {
        self.defaults = defaults
        self.accountID = accountID
        displayName = defaults.string(forKey: "displayName") ?? ""
        dailyGoalML = defaults.object(forKey: "dailyGoalML") as? Int ?? 2400
        entries = (try? JSONDecoder().decode([HydrationEntry].self, from: defaults.data(forKey: "entries") ?? Data())) ?? []
        bottle = (try? JSONDecoder().decode(WaterBottle.self, from: defaults.data(forKey: "bottle") ?? Data()))
    }

    var todayAmountML: Int {
        entries.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.amountML }
    }

    var todayProgress: Double { min(Double(todayAmountML) / Double(max(dailyGoalML, 1)), 1) }

    var statistics: HydrationStatistics { HydrationStatistics(entries: entries, goalML: dailyGoalML) }
    var currentStreak: Int { statistics.currentStreak }

    // Includes zero-intake days, over the last seven calendar days including today.
    var dailyAverageML: Int { statistics.dailyAverageML }

    func addWater(_ amountML: Int) {
        guard (10...7570).contains(amountML) else { return }
        entries.append(HydrationEntry(amountML: amountML))
    }

    func removeEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func amount(on date: Date) -> Int {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amountML }
    }

    func publishWidgetData() {
        guard let accountID, UserDefaults.standard.string(forKey: "activeWidgetAccountID") == accountID else { return }
        HydrationWidgetData(goalML: dailyGoalML, drinks: entries.map {
            .init(date: $0.date, amountML: $0.amountML)
        }).save()
    }

    private func save() {
        publishWidgetData()
        defaults.set(displayName, forKey: "displayName")
        defaults.set(dailyGoalML, forKey: "dailyGoalML")
        defaults.set(try? JSONEncoder().encode(entries), forKey: "entries")
        if let bottle, let data = try? JSONEncoder().encode(bottle) {
            defaults.set(data, forKey: "bottle")
        } else {
            defaults.removeObject(forKey: "bottle")
        }
    }
}
