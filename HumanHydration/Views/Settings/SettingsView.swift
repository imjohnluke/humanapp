import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    var title: String = "Settings"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { AccountSettingsPage(closeSettings: { dismiss() }) } label: {
                        SettingsRowLabel(title: "Account", subtitle: accountSubtitle, icon: "person.crop.circle.fill", tint: .blue)
                    }
                    NavigationLink { SubscriptionSettingsPage() } label: {
                        SettingsRowLabel(title: "Subscription", subtitle: subscriptions.isPro ? "Pro active" : "Free plan", icon: "creditcard.fill", tint: .indigo)
                    }
                }
                Section {
                    NavigationLink { HydrationSettingsPage() } label: {
                        SettingsRowLabel(title: "Hydration", subtitle: "Daily goal and bottle", icon: "drop.fill", tint: .cyan)
                    }
                    NavigationLink { NotificationSettingsPage() } label: {
                        SettingsRowLabel(title: "Notifications", subtitle: "Daily reminder", icon: "bell.badge.fill", tint: .red)
                    }
                    NavigationLink { HealthSettingsPage() } label: {
                        SettingsRowLabel(title: "Health", subtitle: "Apple Health connection", icon: "heart.fill", tint: .pink)
                    }
                }
                Section {
                    NavigationLink { AppearanceSettingsPage() } label: {
                        SettingsRowLabel(title: "Appearance", subtitle: nil, icon: "circle.lefthalf.filled", tint: .gray)
                    }
                    NavigationLink { IslandAndWidgetsSettingsPage() } label: {
                        SettingsRowLabel(title: "Dynamic Island & widgets", subtitle: nil, icon: "square.grid.2x2.fill", tint: .orange)
                    }
                }
                Section {
                    NavigationLink { AboutSettingsPage() } label: {
                        SettingsRowLabel(title: "About", subtitle: nil, icon: "info.circle.fill", tint: .teal)
                    }
                }
            }
            .navigationTitle(title)
            .scrollContentBackground(.hidden)
            .background(HydrationTheme.canvas.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var accountSubtitle: String {
        let name = store.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? (auth.user?.email ?? "Name, email, log out") : name
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private extension View {
    func settingsPage(_ title: String) -> some View {
        self.navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(HydrationTheme.canvas.ignoresSafeArea())
    }
}

// MARK: - Account

private struct AccountSettingsPage: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var auth: AuthService
    let closeSettings: () -> Void
    @State private var confirmingDelete = false
    @State private var deletingAccount = false

    var body: some View {
        Form {
            Section("Name") {
                TextField("Your name", text: $store.displayName).textContentType(.name)
            }
            if let email = auth.user?.email {
                Section { LabeledContent("Email", value: email) }
            }
            Section {
                Button(role: .destructive) {
                    closeSettings()
                    auth.signOut()
                } label: {
                    Text("Log out").font(.headline.weight(.regular))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent).tint(.red)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .disabled(auth.isLoading)
            }
            Section {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    HStack {
                        if deletingAccount { ProgressView() }
                        Text("Delete account").font(.headline.weight(.regular))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                }
                .buttonStyle(.borderedProminent).tint(.red)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .disabled(auth.isLoading || deletingAccount)
                if let error = auth.errorMessage, !deletingAccount {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } footer: {
                Text("Permanently deletes your account and the hydration data stored for it. Apple subscriptions are billed separately and can be canceled under Subscription.")
            }
        }
        .settingsPage("Account")
        .alert("Delete your account?", isPresented: $confirmingDelete) {
            Button("Delete account", role: .destructive) {
                Task {
                    deletingAccount = true
                    let deleted = await auth.deleteAccount()
                    deletingAccount = false
                    if deleted { closeSettings() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your Human Hydration account and the data stored for it. This cannot be undone. Apple subscriptions stay with your Apple ID until you cancel them.")
        }
    }
}

// MARK: - Subscription

private struct SubscriptionSettingsPage: View {
    @EnvironmentObject private var subscriptions: SubscriptionService

    var body: some View {
        Form {
            Section {
                LabeledContent("Plan", value: subscriptions.isPro ? "Pro" : "Free")
            }
            Section {
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Label("Manage subscription", systemImage: "creditcard")
                }
            }
        }
        .settingsPage("Subscription")
    }
}

// MARK: - Hydration

private struct HydrationSettingsPage: View {
    @EnvironmentObject private var store: HydrationStore
    @State private var showingBottlePicker = false

    var body: some View {
        Form {
            Section("Daily goal") {
                Stepper("\(WaterVolume.label(store.dailyGoalML))", value: Binding(
                    get: { Int(WaterVolume.ounces(store.dailyGoalML).rounded()) },
                    set: { store.dailyGoalML = Int((Double($0) * WaterVolume.mlPerOunce).rounded()) }
                ), in: 128...400, step: 1)
                Text("One gallon is the minimum tracking target. Your body size and workout routine may set it higher.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Bottle") {
                Button { showingBottlePicker = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.bottle.map { BottleCatalog.displayName($0.name) } ?? "Choose your bottle")
                            if let bottle = store.bottle {
                                Text(BottleCatalog.sizeLabel(capacityML: bottle.capacityML))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }.foregroundStyle(.primary)
                }
            }
        }
        .settingsPage("Hydration")
        .sheet(isPresented: $showingBottlePicker) { BottlePickerSheet() }
    }
}

// MARK: - Notifications

private struct NotificationSettingsPage: View {
    @EnvironmentObject private var auth: AuthService
    @State private var remindersEnabled = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 10)) ?? .now
    @State private var savingReminder = false
    @State private var reminderError: String?

    var body: some View {
        Form {
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
            } footer: {
                Text("One optional reminder each day. Logging out turns it off.")
            }
        }
        .settingsPage("Notifications")
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
                    reminderError = "Notifications are off. Enable them for Human Hydration in iPhone Settings."
                    return
                }
                guard auth.isAuthenticated else { return }
                let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                try await service.scheduleDailyReminder(at: time.hour ?? 10, minute: time.minute ?? 0)
                if !auth.isAuthenticated { service.cancel() }
            } catch {
                remindersEnabled = false
                reminderError = "Couldn\u{2019}t save that reminder. Please try again."
            }
        }
    }
}

// MARK: - Health

private struct HealthSettingsPage: View {
    var body: some View {
        Form {
            Section { HealthConnectionCard() }
        }
        .settingsPage("Health")
    }
}

// MARK: - Appearance

private struct AppearanceSettingsPage: View {
    @AppStorage("appearancePreference") private var appearance = AppearancePreference.system.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("System follows your iPhone\u{2019}s current appearance.")
            }
        }
        .settingsPage("Appearance")
    }
}

// MARK: - Dynamic Island & widgets

private struct IslandAndWidgetsSettingsPage: View {
    var body: some View {
        Form {
            Section {
                LiveIslandControl()
            } header: {
                Text("Dynamic Island")
            } footer: {
                Text("Pro can keep today\u{2019}s water on your iPhone. Press and hold the island, then tap Log to add your usual drink. Home Screen widgets use the same Log button.")
            }
            Section {
                NavigationLink { WidgetGalleryView() } label: {
                    Label("Home & Lock Screen widgets", systemImage: "square.grid.2x2")
                }
            }
        }
        .settingsPage("Dynamic Island & widgets")
    }
}

// MARK: - About

private struct AboutSettingsPage: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("App", value: "Human Hydration")
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
            Section {
                Text("Hydration goals are editable tracking targets, not medical advice. Follow any fluid limits given by your clinician.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .settingsPage("About")
    }
}
