import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var remindersEnabled = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 10)) ?? .now
    @State private var savingReminder = false
    @State private var reminderError: String?
    var title: String = "Settings"
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Your name", text: $store.displayName).textContentType(.name)
                }
                Section("Daily goal") {
                    Stepper("\(store.dailyGoalML) ml", value: $store.dailyGoalML, in: 500...6000, step: 100)
                }
                Section("Bottle") {
                    Toggle("I use a water bottle", isOn: Binding(get: { store.bottle != nil }, set: { store.bottle = $0 ? WaterBottle() : nil }))
                    if let bottle = store.bottle { Text("\(bottle.name) · \(bottle.capacityML) ml").foregroundStyle(.secondary) }
                }
                Section {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                        Label("Manage subscription", systemImage: "creditcard")
                    }
                } header: { Text("Subscription") } footer: {
                    Text("Manage subscriptions billed through Apple. No paid plan is configured in human yet.")
                }
                Section("Personalize") {
                    NavigationLink { WidgetGalleryView() } label: {
                        Label("Home & Lock Screen widgets", systemImage: "square.grid.2x2")
                    }
                }
                Section {
                    if let email = auth.user?.email {
                        LabeledContent("Signed in as", value: email)
                    }
                    Button("Log out", role: .destructive) {
                        dismiss()
                        auth.signOut()
                    }
                } header: { Text("Account") } footer: {
                    Text("Logs remain on this device. Widget data is hidden while logged out.")
                }
                Section {
                    Toggle("Daily reminder", isOn: $remindersEnabled)
                        .disabled(savingReminder)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled { scheduleReminder() } else { ReminderService().cancel() }
                        }
                    if remindersEnabled {
                        DatePicker("Remind me at", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .disabled(savingReminder)
                            .onChange(of: reminderTime) { _, _ in scheduleReminder() }
                    }
                    if let reminderError { Text(reminderError).font(.caption).foregroundStyle(.red) }
                } header: { Text("Reminders") } footer: {
                    Text("One optional reminder each day. Logging out turns it off.")
                }
                Section("About") {
                    LabeledContent("App", value: "human app")
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    Text("Hydration goals are editable tracking targets, not medical advice. Follow any fluid limits given by your clinician.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle(title)
                .scrollContentBackground(.hidden)
                .background(HydrationTheme.canvas.ignoresSafeArea())
        }
        .task {
            let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            if let trigger = requests.first(where: { $0.identifier == "daily-water-reminder" })?.trigger as? UNCalendarNotificationTrigger {
                reminderTime = Calendar.current.date(from: trigger.dateComponents) ?? reminderTime
                remindersEnabled = true
            }
        }
    }

    private func scheduleReminder() {
        guard !savingReminder else { return }
        savingReminder = true
        reminderError = nil
        Task {
            defer { savingReminder = false }
            do {
                let service = ReminderService()
                guard try await service.requestPermission() else {
                    remindersEnabled = false
                    reminderError = "Notifications are off. Enable them for human app in iPhone Settings."
                    return
                }
                guard auth.isAuthenticated else { return }
                let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                try await service.scheduleDailyReminder(at: time.hour ?? 10, minute: time.minute ?? 0)
                if !auth.isAuthenticated { service.cancel() }
            } catch {
                remindersEnabled = false
                reminderError = "Couldn’t save that reminder. Please try again."
            }
        }
    }
}
