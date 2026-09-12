import HealthKit

final class HealthKitService {
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable(),
              let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return }
        try await store.requestAuthorization(toShare: [waterType], read: [waterType])
    }

    func saveWater(amountML: Double, date: Date = .now) async throws {
        guard let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountML)
        try await store.save(HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date))
    }
}
