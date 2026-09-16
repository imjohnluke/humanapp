import Foundation
import WidgetKit

struct HydrationWidgetData: Codable {
    struct Drink: Codable { let date: Date; let amountML: Int }
    var goalML: Int
    var drinks: [Drink]
    static let kind = "HumanHydrationWidget"
    static let fillKind = "HumanHydrationFillWidget"
    static let suite = "group.com.humanhydration.app"
    static let key = "hydrationWidgetData"
    func amount(on date: Date) -> Int {
        drinks.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amountML }
    }
    static func read() -> Self? {
        if let data = fileData ?? UserDefaults(suiteName: suite)?.data(forKey: key) {
            return try? JSONDecoder().decode(Self.self, from: data)
        }
        return nil
    }
    func save() {
        guard let encoded = try? JSONEncoder().encode(self) else { return }
        write(encoded)
        Self.reload()
    }
    static func clear() {
        UserDefaults(suiteName: suite)?.removeObject(forKey: key)
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        reload()
    }

    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite)?
            .appendingPathComponent("\(key).json")
    }
    private static var fileData: Data? {
        guard let url = fileURL else { return nil }
        return try? Data(contentsOf: url)
    }
    private func write(_ data: Data) {
        let defaults = UserDefaults(suiteName: Self.suite)
        defaults?.set(data, forKey: Self.key)
        defaults?.synchronize()
        if let url = Self.fileURL {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }
    private static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        WidgetCenter.shared.reloadTimelines(ofKind: fillKind)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
