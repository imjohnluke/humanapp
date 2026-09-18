import Foundation

enum AccountStorage {
    static func suiteName(for userID: UUID) -> String {
        "com.humanhydration.account.\(userID.uuidString.lowercased())"
    }

    static func defaults(for userID: UUID) -> UserDefaults {
        UserDefaults(suiteName: suiteName(for: userID))!
    }

    static func wipe(_ userID: UUID) {
        let name = suiteName(for: userID)
        guard let defaults = UserDefaults(suiteName: name) else { return }
        defaults.removePersistentDomain(forName: name)
        defaults.synchronize()
    }
}
