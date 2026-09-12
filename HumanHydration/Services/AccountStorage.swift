import Foundation

enum AccountStorage {
    static func defaults(for userID: UUID) -> UserDefaults {
        UserDefaults(suiteName: "com.humanhydration.account.\(userID.uuidString.lowercased())")!
    }
}
