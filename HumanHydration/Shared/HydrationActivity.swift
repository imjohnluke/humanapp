import ActivityKit
import AppIntents
import Foundation

struct HydrationActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var amountML: Int
        var goalML: Int
        var logAmountML: Int
        var logName: String

        var progress: Double { min(Double(amountML) / Double(max(goalML, 1)), 1) }
        var remainingML: Int { max(goalML - amountML, 0) }
        var reached: Bool { goalML > 0 && amountML >= goalML }

        init(data: HydrationWidgetData) {
            amountML = data.amount(on: .now)
            goalML = data.goalML
            logAmountML = data.logAmountML
            logName = data.logName
        }

        init(amountML: Int, goalML: Int, logAmountML: Int, logName: String) {
            self.amountML = amountML
            self.goalML = goalML
            self.logAmountML = logAmountML
            self.logName = logName
        }
    }
}

enum HydrationActivityCenter {
    @MainActor
    static func apply(enabled: Bool, amountML: Int, goalML: Int, logAmountML: Int, logName: String) async -> Bool {
        if !enabled {
            await end()
            return true
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let state = HydrationActivityAttributes.ContentState(
            amountML: amountML,
            goalML: goalML,
            logAmountML: max(logAmountML, 10),
            logName: logName
        )
        let content = ActivityContent(state: state, staleDate: endOfDay())
        for activity in Activity<HydrationActivityAttributes>.activities where (activity.content.staleDate ?? .distantFuture) < .now {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let current = Activity<HydrationActivityAttributes>.activities
        if current.isEmpty {
            do {
                _ = try Activity.request(attributes: HydrationActivityAttributes(), content: content, pushType: nil)
                return true
            } catch {
                return false
            }
        }
        for activity in current {
            await activity.update(content)
        }
        return true
    }

    static func update(_ data: HydrationWidgetData) async {
        let content = ActivityContent(state: HydrationActivityAttributes.ContentState(data: data), staleDate: endOfDay())
        for activity in Activity<HydrationActivityAttributes>.activities {
            await activity.update(content)
        }
    }

    static func end() async {
        for activity in Activity<HydrationActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func endOfDay() -> Date {
        Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(60 * 60)
    }
}

struct LogWaterIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log water"
    static var description = IntentDescription("Add your usual drink to today’s hydration.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount in milliliters")
    var amountML: Int

    init() { amountML = 0 }

    init(amountML: Int) { self.amountML = amountML }

    func perform() async throws -> some IntentResult {
        let stored = HydrationWidgetData.read()
        let amount = (10...7570).contains(amountML) ? amountML : (stored?.logAmountML ?? 0)
        guard let data = HydrationWidgetData.log(amountML: amount) else { return .result() }
        await HydrationActivityCenter.update(data)
        return .result()
    }
}
