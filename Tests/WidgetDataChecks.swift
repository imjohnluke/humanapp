import Foundation

@main
enum WidgetDataChecks {
    static func main() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        var data = HydrationWidgetData(goalML: 2400, drinks: [
            .init(date: yesterday, amountML: 800),
            .init(date: today, amountML: 250),
            .init(date: today.addingTimeInterval(60), amountML: 500)
        ])
        precondition(data.amount(on: today) == 750, "Only today's drinks count")
        precondition(data.amount(on: tomorrow) == 0, "Midnight resets the total")
        precondition(data.amount(on: yesterday) == 800, "Historical totals remain separate")
        data.drinks.removeLast()
        precondition(data.amount(on: today) == 250, "Removed water is reflected")
        let decoded = try JSONDecoder().decode(HydrationWidgetData.self, from: JSONEncoder().encode(data))
        precondition(decoded.goalML == 2400 && decoded.amount(on: today) == 250)
        print("Widget data checks passed: day filtering, midnight, removal, encoding.")
    }
}
