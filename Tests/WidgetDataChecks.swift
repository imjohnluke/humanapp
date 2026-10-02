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
        let loggedID = UUID()
        let logged = HydrationWidgetData(goalML: 2400, drinks: [.init(date: today, amountML: 250, id: loggedID, pendingImport: true)], logAmountML: 300, logName: "Glass")
        precondition(logged.unknownDrinks(knownIDs: []).map(\.id) == [loggedID])
        precondition(logged.unknownDrinks(knownIDs: [loggedID]).isEmpty)
        let published = HydrationWidgetData(goalML: 2400, drinks: [.init(date: today, amountML: 250, id: loggedID)])
        precondition(published.unknownDrinks(knownIDs: []).isEmpty, "Deleted app entries must not be re-imported from an older widget snapshot")
        let roundTrip = try JSONDecoder().decode(HydrationWidgetData.self, from: JSONEncoder().encode(logged))
        precondition(roundTrip.unknownDrinks(knownIDs: []).count == 1, "Pending widget logs survive serialization")
        let legacy = try JSONDecoder().decode(HydrationWidgetData.self, from: Data("{\"goalML\":1000,\"drinks\":[{\"date\":0,\"amountML\":10}]}".utf8))
        precondition(legacy.logAmountML == 250 && legacy.logName == "Glass" && legacy.unknownDrinks(knownIDs: []).isEmpty)
        print("Widget data checks passed: day filtering, midnight, removal, encoding.")
    }
}
