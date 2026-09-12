import Foundation

@main
enum StatisticsChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        // Includes the March daylight-saving transition.
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!
        func entry(_ offset: Int, _ amount: Int) -> HydrationEntry {
            HydrationEntry(amountML: amount, date: calendar.date(byAdding: .day, value: offset, to: now)!)
        }
        func stats(_ entries: [HydrationEntry], goal: Int = 2000) -> HydrationStatistics {
            HydrationStatistics(entries: entries, goalML: goal, now: now, calendar: calendar)
        }
        precondition(stats([]).currentStreak == 0)
        precondition(stats([]).dailyAverageML == 0)
        let past = [entry(-1, 2000), entry(-2, 2000), entry(-3, 2000)]
        precondition(stats(past).currentStreak == 3, "An unfinished today does not break yesterday's streak")
        precondition(stats(past + [entry(0, 1000), entry(0, 1000)]).currentStreak == 4)
        precondition(stats([entry(0, 2000), entry(-2, 2000)]).currentStreak == 1)
        precondition(stats([entry(-2, 2000)]).currentStreak == 0)
        precondition(stats([entry(0, 700)]).dailyAverageML == 100, "Average must include six empty days")
        precondition(stats([entry(-7, 7000), entry(1, 7000)]).dailyAverageML == 0)
        precondition(stats([entry(0, -100)]).dailyAverageML == 0)
        precondition(stats(past, goal: 0).currentStreak == 0)
        precondition(stats(past).week.count == 7)
        precondition(Set(stats(past).week.map(\.date)).count == 7, "DST must not duplicate a day")
        precondition(stats(past).week.allSatisfy { calendar.component(.hour, from: $0.date) == 0 })
        print("PASS: real totals, empty days, seven-day average, streak gaps, today grace, future filtering, DST, invalid goals.")
    }
}
