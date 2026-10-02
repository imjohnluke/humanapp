import Foundation
import WidgetKit

struct HydrationWidgetData: Codable {
    struct Drink: Codable {
        var id: UUID?
        var date: Date
        var amountML: Int
        var pendingImport: Bool?

        init(date: Date, amountML: Int, id: UUID? = nil, pendingImport: Bool = false) {
            self.id = id
            self.pendingImport = pendingImport
            self.date = date
            self.amountML = amountML
        }
    }

    var goalML: Int
    var drinks: [Drink]
    var logAmountML: Int
    var logName: String
    static let kind = "HumanHydrationWidget"
    static let fillKind = "HumanHydrationFillWidget"
    static let suite = "group.com.humanhydration.app"
    static let key = "hydrationWidgetData"
    static let logPing = "com.humanhydration.widget-log" as CFString

    init(goalML: Int, drinks: [Drink], logAmountML: Int = 250, logName: String = "Glass") {
        self.goalML = goalML
        self.drinks = drinks
        self.logAmountML = logAmountML
        self.logName = logName
    }

    func amount(on date: Date) -> Int {
        drinks.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amountML }
    }

    func unknownDrinks(knownIDs: Set<UUID>) -> [Drink] {
        drinks.filter { drink in
            guard drink.pendingImport == true, let id = drink.id, !knownIDs.contains(id), (10...7570).contains(drink.amountML) else { return false }
            return true
        }
    }

    static func read() -> Self? {
        if let data = fileData ?? UserDefaults(suiteName: suite)?.data(forKey: key) {
            return try? JSONDecoder().decode(Self.self, from: data)
        }
        return nil
    }

    /// Append one drink from a widget or Dynamic Island button and tell the app to import it.
    static func log(amountML: Int) -> HydrationWidgetData? {
        guard var data = read(), (10...7570).contains(amountML) else { return nil }
        data.drinks.append(.init(date: .now, amountML: amountML, id: UUID(), pendingImport: true))
        data.save()
        postLogPing()
        return data
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

    static func postLogPing() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(logPing), nil, nil, true)
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

    private enum CodingKeys: String, CodingKey { case goalML, drinks, logAmountML, logName }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goalML = try container.decode(Int.self, forKey: .goalML)
        drinks = try container.decode([Drink].self, forKey: .drinks)
        logAmountML = try container.decodeIfPresent(Int.self, forKey: .logAmountML) ?? 250
        logName = try container.decodeIfPresent(String.self, forKey: .logName) ?? "Glass"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goalML, forKey: .goalML)
        try container.encode(drinks, forKey: .drinks)
        try container.encode(logAmountML, forKey: .logAmountML)
        try container.encode(logName, forKey: .logName)
    }
}
