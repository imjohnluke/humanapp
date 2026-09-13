import HealthKit
import Combine

@MainActor
final class HealthKitService: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var sleepEnabled: Bool
    @Published private(set) var busy = false
    @Published private(set) var workouts: [HKWorkout] = []
    @Published private(set) var bedtime: Date?
    @Published private(set) var error: String?
    private let store = HKHealthStore()
    private let defaults: UserDefaults
    private var generation = 0
    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: "healthInsightsEnabled")
        sleepEnabled = defaults.bool(forKey: "healthSleepEnabled")
    }

    func connect(includeSleep: Bool = false) async {
        guard available, !busy else { return }
        busy = true
        error = nil
        defer { busy = false }
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if includeSleep { types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!) }
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            enabled = true
            sleepEnabled = sleepEnabled || includeSleep
            defaults.set(true, forKey: "healthInsightsEnabled")
            defaults.set(sleepEnabled, forKey: "healthSleepEnabled")
            await refresh()
        } catch {
            self.error = "Couldn’t open Apple Health. Please try again."
        }
    }

    func disconnect() {
        generation += 1
        enabled = false
        sleepEnabled = false
        workouts = []
        bedtime = nil
        error = nil
        defaults.set(false, forKey: "healthInsightsEnabled")
        defaults.set(false, forKey: "healthSleepEnabled")
    }

    func refresh() async {
        guard enabled, available else { return }
        let current = generation
        do {
            let samples = try await read(HKObjectType.workoutType())
            guard enabled, generation == current else { return }
            workouts = samples.compactMap { $0 as? HKWorkout }
            if sleepEnabled {
                let sleep = try await read(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
                guard enabled, generation == current else { return }
                // Earliest asleep sample in the latest sleep session; overlapping sources don't add duration.
                let asleep = sleep.compactMap { $0 as? HKCategorySample }.filter {
                    [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                     HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                     HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                     HKCategoryValueSleepAnalysis.asleepREM.rawValue].contains($0.value)
                }.sorted { $0.startDate < $1.startDate }
                if let latest = asleep.last, latest.endDate > Date.now.addingTimeInterval(-36 * 3600) {
                    var start = latest.startDate
                    for sample in asleep.dropLast().reversed() {
                        guard sample.endDate >= start.addingTimeInterval(-90 * 60) else { break }
                        start = min(start, sample.startDate)
                    }
                    bedtime = start
                } else { bedtime = nil }
            }
            error = nil
        } catch {
            guard enabled, generation == current else { return }
            workouts = []
            bedtime = nil
            self.error = "Couldn’t refresh Health data. Try again when your iPhone is unlocked."
        }
    }

    private func read(_ type: HKSampleType) async throws -> [HKSample] {
        let start = Calendar.current.date(byAdding: .day, value: -28, to: .now)!
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type,
                predicate: HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate),
                limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples ?? []) }
                }
            store.execute(query)
        }
    }

    var routineText: String {
        let calendar = Calendar.current
        let daysByHour = Dictionary(grouping: workouts, by: { calendar.component(.hour, from: $0.startDate) })
            .mapValues { Set($0.map { calendar.startOfDay(for: $0.startDate) }).count }
        if let peak = daysByHour.sorted(by: { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }).first,
           peak.value >= 3 {
            let time = calendar.date(bySettingHour: peak.key, minute: 0, second: 0, of: .now)!
            return "You recorded workouts around \(time.formatted(date: .omitted, time: .shortened)) on \(peak.value) days in the last 4 weeks. Keep your bottle handy around that time."
        }
        return "As more workouts become available, your routine will appear here. We look for at least 3 workout days around the same hour."
    }
    var latestWorkoutText: String? {
        guard let latest = workouts.filter({ Calendar.current.isDateInToday($0.endDate) }).max(by: { $0.endDate < $1.endDate }) else { return nil }
        return "A \(Int(latest.duration / 60))-minute workout was recorded today. Had water afterward? Remember to log what you drank."
    }
}
