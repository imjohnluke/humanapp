import Foundation
import Combine

final class HydrationStore: ObservableObject {
    @Published var displayName: String { didSet { save() } }
    @Published var dailyGoalML: Int { didSet { save() } }
    @Published private(set) var entries: [HydrationEntry] { didSet { save() } }
    @Published private(set) var savedDrinks: [SavedDrink] = []
    @Published var selectedDrinkID: UUID? { didSet { persistDrinks() } }
    @Published private(set) var undoEntry: HydrationEntry?
    @Published var bottle: WaterBottle? { didSet { save() } }

    @Published private(set) var earnedStreakDays: Int
    @Published var liveIslandEnabled: Bool { didSet { defaults.set(liveIslandEnabled, forKey: "liveIslandEnabled") } }
    @Published var liveIslandMessage: String?

    private let defaults: UserDefaults
    private let accountID: String?
    private let calendar = Calendar.current
    private var widgetAccessEnabled = false

    init(defaults: UserDefaults = .standard, accountID: String? = nil) {
        self.defaults = defaults
        self.accountID = accountID
        widgetAccessEnabled = defaults.bool(forKey: "widgetAccessEnabled") || defaults.bool(forKey: "cachedIsPro")
        liveIslandEnabled = defaults.bool(forKey: "liveIslandEnabled")
        savedDrinks = ((try? JSONDecoder().decode([SavedDrink].self, from: defaults.data(forKey: "savedDrinks") ?? Data())) ?? [])
            .filter { (40...7570).contains($0.capacityML) && !$0.name.isEmpty }
        selectedDrinkID = defaults.string(forKey: "selectedDrinkID").flatMap(UUID.init(uuidString:))
        displayName = defaults.string(forKey: "displayName") ?? ""
        let loadedGoal = max(defaults.object(forKey: "dailyGoalML") as? Int ?? HydrationGoalCalculator.gallonML,
                             HydrationGoalCalculator.gallonML)
        let loadedEntries = (try? JSONDecoder().decode([HydrationEntry].self, from: defaults.data(forKey: "entries") ?? Data())) ?? []
        let loggedAway = widgetAccessEnabled
            ? (HydrationWidgetData.read()?.unknownDrinks(knownIDs: Set(loadedEntries.map(\.id))) ?? [])
            : []
        let mergedEntries = loadedEntries + loggedAway.map { HydrationEntry(amountML: $0.amountML, date: $0.date, id: $0.id ?? UUID()) }
        dailyGoalML = loadedGoal
        entries = mergedEntries
        bottle = (try? JSONDecoder().decode(WaterBottle.self, from: defaults.data(forKey: "bottle") ?? Data()))
        earnedStreakDays = max(defaults.integer(forKey: "earnedStreakDays"), HydrationStatistics(entries: mergedEntries, goalML: loadedGoal).bestStreak)
        defaults.set(earnedStreakDays, forKey: "earnedStreakDays")
        if let savedBottle = bottle, BottleCatalog.finish(savedBottle.colorName) == nil {
            bottle?.colorName = "clear"
        }
        // Existing accounts already picked a bottle before usual drinks were introduced.
        if savedDrinks.isEmpty, let bottle { useBottleForLogging(bottle) }
        if !loggedAway.isEmpty { save() }
    }

    var todayAmountML: Int {
        entries.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.amountML }
    }

    var todayProgress: Double { min(Double(todayAmountML) / Double(max(dailyGoalML, 1)), 1) }

    var statistics: HydrationStatistics { HydrationStatistics(entries: entries, goalML: dailyGoalML) }
    var currentStreak: Int { statistics.currentStreak }
    var bestStreak: Int { statistics.bestStreak }

    // Includes zero-intake days, over the last seven calendar days including today.
    var dailyAverageML: Int { statistics.dailyAverageML }

    func addWater(_ amountML: Int) {
        guard (10...7570).contains(amountML) else { return }
        let entry = HydrationEntry(amountML: amountML)
        entries.append(entry)
        undoEntry = entry
    }

    var selectedDrink: SavedDrink? {
        savedDrinks.first { $0.id == selectedDrinkID } ?? savedDrinks.first
    }

    func selectBottle(_ value: WaterBottle) {
        bottle = value
        useBottleForLogging(value)
    }

    private func useBottleForLogging(_ value: WaterBottle) {
        if let existing = savedDrinks.first(where: { $0.name == value.name && $0.capacityML == value.capacityML }) {
            selectedDrinkID = existing.id
        } else {
            saveDrink(name: value.name, capacityML: value.capacityML, isEstimate: true)
        }
    }

    func saveDrink(name: String, capacityML: Int, isEstimate: Bool) {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !name.isEmpty, (40...7570).contains(capacityML) else { return }
        let drink = SavedDrink(name: name, capacityML: capacityML, isEstimate: isEstimate)
        savedDrinks.append(drink)
        selectedDrinkID = drink.id
        persistDrinks()
    }

    func deleteDrink(_ drink: SavedDrink) {
        savedDrinks.removeAll { $0.id == drink.id }
        if selectedDrinkID == drink.id { selectedDrinkID = savedDrinks.first?.id }
        persistDrinks()
    }

    func undoLastLog() {
        guard let entry = undoEntry else { return }
        removeEntry(entry)
        undoEntry = nil
    }

    private func persistDrinks() {
        defaults.set(try? JSONEncoder().encode(savedDrinks), forKey: "savedDrinks")
        defaults.set(selectedDrinkID?.uuidString, forKey: "selectedDrinkID")
        publishWidgetData()
    }

    /// Correct today's most recent drinks, preserving earlier days and entry identities.
    func subtractWater(_ amountML: Int) {
        guard amountML > 0 else { return }
        var remaining = amountML
        var updated = entries
        let indices = updated.indices
            .filter { calendar.isDateInToday(updated[$0].date) }
            .sorted { updated[$0].date > updated[$1].date }
        for index in indices where remaining > 0 {
            let entry = updated[index]
            let reduction = min(entry.amountML, remaining)
            remaining -= reduction
            updated[index] = HydrationEntry(amountML: entry.amountML - reduction, date: entry.date, id: entry.id)
        }
        let emptiedIDs = Set(indices.filter { updated[$0].amountML == 0 }.map { updated[$0].id })
        entries = updated.filter { !emptiedIDs.contains($0.id) }
    }

    func removeEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func amount(on date: Date) -> Int {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amountML }
    }

    func isFinishUnlocked(_ finish: String) -> Bool {
        guard let tier = BottleCatalog.finish(finish) else { return false }
        return earnedStreakDays >= tier.days
    }

    func importWidgetLogs() {
        guard widgetAccessEnabled, let remote = HydrationWidgetData.read() else { return }
        if let accountID, let active = UserDefaults.standard.string(forKey: "activeWidgetAccountID"), active != accountID {
            return
        }
        let fresh = remote.unknownDrinks(knownIDs: Set(entries.map(\.id)))
        guard !fresh.isEmpty else { return }
        entries.append(contentsOf: fresh.map { HydrationEntry(amountML: $0.amountML, date: $0.date, id: $0.id ?? UUID()) })
    }

    func publishWidgetData() {
        guard widgetAccessEnabled else { return }
        if let accountID, let active = UserDefaults.standard.string(forKey: "activeWidgetAccountID"), active != accountID {
            return
        }
        var drinks = entries.map { HydrationWidgetData.Drink(date: $0.date, amountML: $0.amountML, id: $0.id) }
        let known = Set(drinks.compactMap(\.id))
        if let remote = HydrationWidgetData.read() {
            drinks.append(contentsOf: remote.unknownDrinks(knownIDs: known))
        }
        let drink = selectedDrink
        HydrationWidgetData(
            goalML: dailyGoalML,
            drinks: drinks,
            logAmountML: drink?.capacityML ?? 250,
            logName: drink.map { BottleCatalog.displayName($0.name) } ?? "Glass"
        ).save()
    }

    func setWidgetAccess(_ enabled: Bool) {
        widgetAccessEnabled = enabled
        defaults.set(enabled, forKey: "widgetAccessEnabled")
        if enabled { publishWidgetData() } else { HydrationWidgetData.clear() }
    }

    private func save() {
        let record = max(earnedStreakDays, statistics.bestStreak)
        if earnedStreakDays != record { earnedStreakDays = record }
        defaults.set(earnedStreakDays, forKey: "earnedStreakDays")
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
