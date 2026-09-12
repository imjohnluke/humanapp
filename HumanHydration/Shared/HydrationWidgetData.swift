import Foundation
import WidgetKit

struct HydrationWidgetData: Codable {
    struct Drink: Codable { let date: Date; let amountML: Int }
    var goalML: Int
    var drinks: [Drink]
    static let suite = "group.com.humanhydration.app"
    static let key = "hydrationWidgetData"
    func amount(on date: Date) -> Int {
        drinks.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amountML }
    }
    static func read() -> Self? {
        guard let data = UserDefaults(suiteName: suite)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    func save() {
        UserDefaults(suiteName: Self.suite)?.set(try? JSONEncoder().encode(self), forKey: Self.key)
        WidgetCenter.shared.reloadAllTimelines()
    }
    static func clear() {
        UserDefaults(suiteName: suite)?.removeObject(forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
