import UserNotifications

final class ReminderService {
    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func scheduleDailyReminder(at hour: Int = 10, minute: Int = 0) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Time for some water"
        content.body = "Keep your hydration goal moving."
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-water-reminder", content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-water-reminder"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["daily-water-reminder"])
    }
}
