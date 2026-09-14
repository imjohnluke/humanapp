import Foundation

@main
struct HydrationAdjustmentChecks {
    static func main() throws {
        precondition(WaterVolume.milliliters("16") == 473)
        precondition(WaterVolume.milliliters("32") == 946)
        precondition(WaterVolume.milliliters("128") == 3785)
        precondition(WaterVolume.milliliters("nan") == nil && WaterVolume.milliliters("999999999") == nil)
        precondition(WaterVolume.milliliters("0") == nil && WaterVolume.milliliters("-5") == nil)
        precondition(BottleCatalog.sizeLabel(capacityML: 3785) == "1 gallon")
        precondition(HydrationGoalCalculator.dailyGoalML(weightPounds: 170, workoutsPerWeek: 0, workoutMinutes: 60) == 3785)
        precondition(HydrationGoalCalculator.dailyGoalML(weightPounds: 250, workoutsPerWeek: 7, workoutMinutes: 60) > 3785)
        precondition(HydrationGoalCalculator.workoutAdjustmentML(workoutsPerWeek: 7, workoutMinutes: 60) == 400)
        let domain = "hydration-adjustment-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let today = Calendar.current.startOfDay(for: .now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let past = HydrationEntry(amountML: 600, date: yesterday)
        let first = HydrationEntry(amountML: 300, date: today)
        let latest = HydrationEntry(amountML: 100, date: today.addingTimeInterval(1))
        defaults.set(try JSONEncoder().encode([latest, past, first]), forKey: "entries")
        let store = HydrationStore(defaults: defaults)
        store.subtractWater(250)
        precondition(store.todayAmountML == 150)
        precondition(store.amount(on: yesterday) == 600)
        precondition(!store.entries.contains { $0.id == latest.id })
        let remaining = store.entries.first { $0.id == first.id }!
        precondition(remaining.amountML == 150 && remaining.date == first.date)
        precondition(HydrationStore(defaults: defaults).todayAmountML == 150)
        store.subtractWater(250)
        precondition(store.todayAmountML == 0 && store.entries.count == 1)
        store.subtractWater(250)
        store.subtractWater(-100)
        precondition(store.entries.count == 1 && store.amount(on: yesterday) == 600)
        store.addWater(250)
        precondition(store.todayAmountML == 250)
        precondition(store.isFinishUnlocked("clear") && !store.isFinishUnlocked("black"))
        let finishes = ["clear", "black", "bronze", "silver", "gold", "platinum"]
        precondition(BottleCatalog.finishes.map(\.id) == finishes)
        for style in BottleCatalog.options {
            precondition(BottleCatalog.colors(for: style.0) == finishes)
        }
        for finish in BottleCatalog.finishes where finish.days > 0 {
            for count in [finish.days - 1, finish.days] {
                defaults.removePersistentDomain(forName: domain)
                let history = (1...count).map { day in
                    HydrationEntry(amountML: HydrationGoalCalculator.gallonML, date: Calendar.current.date(byAdding: .day, value: -day, to: today)!)
                }
                defaults.set(try JSONEncoder().encode(history), forKey: "entries")
                let rewards = HydrationStore(defaults: defaults)
                precondition(rewards.isFinishUnlocked(finish.id) == (count >= finish.days))
                if count == finish.days {
                    rewards.bottle = WaterBottle(colorName: finish.id)
                    for entry in rewards.entries { rewards.removeEntry(entry) }
                    let restored = HydrationStore(defaults: defaults)
                    precondition(restored.isFinishUnlocked(finish.id), "Earned finish persists")
                    precondition(restored.bottle?.colorName == finish.id)
                }
            }
        }
        defaults.removePersistentDomain(forName: domain)
        let sixDays = (1...6).map { day in
            HydrationEntry(amountML: HydrationGoalCalculator.gallonML, date: Calendar.current.date(byAdding: .day, value: -day, to: today)!)
        }
        defaults.set(try JSONEncoder().encode(sixDays), forKey: "entries")
        let liveRewards = HydrationStore(defaults: defaults)
        liveRewards.addWater(HydrationGoalCalculator.gallonML - 10)
        precondition(!liveRewards.isFinishUnlocked("black"))
        liveRewards.addWater(10)
        precondition(liveRewards.isFinishUnlocked("black"), "Unlock immediately when today's goal is reached")
        defaults.removePersistentDomain(forName: domain)
        defaults.set(try JSONEncoder().encode(WaterBottle(colorName: "purple")), forKey: "bottle")
        precondition(HydrationStore(defaults: defaults).bottle?.colorName == "clear")
        precondition(!HydrationStore(defaults: defaults).isFinishUnlocked("black"), "Rewards remain account scoped")
        defaults.removePersistentDomain(forName: domain)
        let drinks = HydrationStore(defaults: defaults)
        drinks.saveDrink(name: " My glass ", capacityML: 301, isEstimate: true)
        let glass = drinks.selectedDrink!
        precondition(glass.name == "My glass" && glass.amount(quarters: 1) == 75 && glass.amount(quarters: 2) == 151)
        precondition(glass.amount(quarters: 4) == 301)
        drinks.saveDrink(name: "", capacityML: 500, isEstimate: false)
        drinks.saveDrink(name: "Invalid", capacityML: 0, isEstimate: false)
        precondition(drinks.savedDrinks.count == 1)
        let restoredDrinks = HydrationStore(defaults: defaults)
        precondition(restoredDrinks.selectedDrink == glass, "Selected drink and capacity persist")
        restoredDrinks.addWater(glass.amount(quarters: 2))
        restoredDrinks.addWater(200)
        precondition(restoredDrinks.selectedDrink == glass, "One-off manual amounts never change the saved drink")
        restoredDrinks.undoLastLog()
        precondition(restoredDrinks.todayAmountML == 151, "Undo removes only the last log")
        restoredDrinks.undoLastLog()
        precondition(restoredDrinks.todayAmountML == 151, "Undo cannot remove two entries")
        restoredDrinks.deleteDrink(glass)
        precondition(HydrationStore(defaults: defaults).savedDrinks.isEmpty)
        precondition(restoredDrinks.todayAmountML == 151, "Deleting a saved drink preserves intake")
        defaults.removePersistentDomain(forName: domain)
        let oldBottle = WaterBottle(name: "My bottle", capacityML: 750)
        defaults.set(try JSONEncoder().encode(oldBottle), forKey: "bottle")
        let migrated = HydrationStore(defaults: defaults)
        precondition(migrated.selectedDrink?.capacityML == 750, "Existing bottle becomes usual drink")
        let originalID = migrated.selectedDrink?.id
        migrated.selectBottle(oldBottle)
        precondition(migrated.selectedDrink?.id == originalID && migrated.savedDrinks.count == 1, "Selecting same bottle does not duplicate")
        migrated.selectBottle(WaterBottle(name: "New bottle", capacityML: 500))
        precondition(migrated.selectedDrink?.capacityML == 500)
        precondition(HydrationStore(defaults: defaults).selectedDrink?.capacityML == 500, "Bottle selection persists for Home")
        print("PASS: saved drink validation, portions, persistence, deletion and exact-entry Undo")
        print("Reward checks passed: all styles, thresholds, live unlock, persistence, legacy finishes, account isolation")
        print("Hydration adjustment checks passed")
    }
}
