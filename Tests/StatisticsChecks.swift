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
        precondition(stats([]).bestStreak == 0)
        precondition(stats(past).bestStreak == 3, "Best streak spans DST and ignores unfinished today")
        precondition(stats(past + [entry(0, 1000), entry(0, 1000)]).bestStreak == 4)
        let oldRecord = (-15 ... -10).map { entry($0, 2000) }
        precondition(stats(oldRecord + past).bestStreak == 6, "Keep a past record after the streak breaks")
        precondition(stats([entry(-3, 2000), entry(-2, 1999), entry(-1, 4000)]).bestStreak == 1)
        precondition(stats([entry(-2, 2000), entry(0, 2000), entry(1, 2000)]).bestStreak == 1)
        precondition(stats(past, goal: 0).bestStreak == 0)
        precondition(stats(past, goal: -1).bestStreak == 0)
        let yesterdayMorning = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 9))!
        let yesterdayEvening = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 18))!
        let hourly = stats([
            HydrationEntry(amountML: 300, date: yesterdayMorning),
            HydrationEntry(amountML: 200, date: yesterdayMorning),
            HydrationEntry(amountML: 900, date: yesterdayEvening),
            entry(0, 250), entry(1, 1000), entry(0, -100)
        ])
        precondition(hourly.hourlyIntake.count == 24)
        precondition(hourly.hourlyIntake[9].yesterdayML == 500)
        precondition(hourly.hourlyIntake[18].yesterdayML == 900)
        precondition(hourly.hourlyIntake[12].todayML == 250)
        precondition(hourly.yesterdayAmountByNow == 500, "Comparison excludes yesterday's later drinks")
        precondition(hourly.comparisonInsight.contains("8.5 fl oz less"))
        precondition(stats([entry(-1, 250), entry(0, 500)]).comparisonInsight.contains("8.5 fl oz more"))
        precondition(stats([entry(-1, 250), entry(0, 250)]).comparisonInsight.contains("same amount"))
        precondition(stats([]).comparisonInsight.contains("No water was logged"))
        precondition(stats([entry(0, 2000)]).habitInsight.contains("reached today’s target"))
        let midnight = calendar.startOfDay(for: now)
        let midnightStats = HydrationStatistics(entries: [HydrationEntry(amountML: 300, date: yesterdayMorning)], goalML: 2000, now: midnight, calendar: calendar)
        precondition(midnightStats.yesterdayAmountByNow == 0)
        let dstNow = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        let dstMorning = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 11, minute: 30))!
        let dstLater = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12, minute: 30))!
        let dstStats = HydrationStatistics(entries: [HydrationEntry(amountML: 300, date: dstMorning), HydrationEntry(amountML: 500, date: dstLater)], goalML: 2000, now: dstNow, calendar: calendar)
        precondition(dstStats.yesterdayAmountByNow == 300, "Compare local clock time across DST")
        print("PASS: hourly buckets, same-time comparisons, missing logs, midnight, DST, and goal insights.")
        print("PASS: personal record, past streaks, partial goals, split logs, gaps, future entries, and DST.")
        print("PASS: real totals, empty days, seven-day average, streak gaps, today grace, future filtering, DST, invalid goals.")
    }
}
