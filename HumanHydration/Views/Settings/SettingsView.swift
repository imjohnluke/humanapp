import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showingBottlePicker = false
    @State private var remindersEnabled = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 10)) ?? .now
    @State private var savingReminder = false
    @State private var reminderError: String?
    @State private var confirmingDelete = false
    @State private var deletingAccount = false
    @AppStorage("appearancePreference") private var appearance = AppearancePreference.system.rawValue
    var title: String = "Settings"
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Your name", text: $store.displayName).textContentType(.name)
                }
                if let email = auth.user?.email {
                    Section {
                        LabeledContent("Email", value: email)
                    }
                }
                Section("Daily goal") {
                    Stepper("\(WaterVolume.label(store.dailyGoalML))", value: Binding(
                        get: { Int(WaterVolume.ounces(store.dailyGoalML).rounded()) },
                        set: { store.dailyGoalML = Int((Double($0) * WaterVolume.mlPerOunce).rounded()) }
                    ), in: 128...400, step: 1)
                    Text("One gallon is the minimum tracking target. Your body size and workout routine may set it higher.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                appearanceSection
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
                Section {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                        Label("Manage subscription", systemImage: "creditcard")
                    }
                }
                Section {
                    NavigationLink { WidgetGalleryView() } label: {
                        Label("Home & Lock Screen widgets", systemImage: "square.grid.2x2")
                    }
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
                Section {
                    HealthConnectionCard()
                }
                Section("About") {
                    LabeledContent("App", value: "Hydrate: By Human Goods")
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    Text("Hydration goals are editable tracking targets, not medical advice. Follow any fluid limits given by your clinician.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button(role: .destructive) {
                        dismiss()
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
                    Text("Permanently deletes your account and the hydration data stored for it. Apple subscriptions are billed separately and can be canceled in Manage subscription.")
                }
            }.navigationTitle(title)
                .scrollContentBackground(.hidden)
                .background(HydrationTheme.canvas.ignoresSafeArea())
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $showingBottlePicker) { BottlePickerSheet() }
                .alert("Delete your account?", isPresented: $confirmingDelete) {
                    Button("Delete account", role: .destructive) {
                        Task {
                            deletingAccount = true
                            let deleted = await auth.deleteAccount()
                            deletingAccount = false
                            if deleted { dismiss() }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently deletes your Human Hydration account and the data stored for it. This cannot be undone. Apple subscriptions stay with your Apple ID until you cancel them.")
                }
        }
        .task {
            let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            if let trigger = requests.first(where: { $0.identifier == "daily-water-reminder" })?.trigger as? UNCalendarNotificationTrigger {
                reminderTime = Calendar.current.date(from: trigger.dateComponents) ?? reminderTime
                remindersEnabled = true
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Appearance")
        } footer: {
            Text("System follows your iPhone’s current appearance.")
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
                    reminderError = "Notifications are off. Enable them for Hydrate in iPhone Settings."
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
