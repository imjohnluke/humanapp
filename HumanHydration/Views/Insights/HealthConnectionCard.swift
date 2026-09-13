import SwiftUI

struct HealthConnectionCard: View {
    @EnvironmentObject private var health: HealthKitService
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Apple Health", systemImage: "heart.fill")
                .font(.title3).foregroundStyle(.pink)
            Text(health.enabled ? "Your routine, connected" : "A plan that fits your routine")
                .font(.headline.weight(.regular))
            Text("Use workouts from Apple Watch and apps that save to Health to find your usual workout times. Optionally add sleep for evening check-ins.")
                .font(.subheadline).foregroundStyle(.secondary)
            if health.available {
                if health.enabled {
                    Text("Access requested · \(health.workouts.count) workouts available")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("No data? You may have no records or sharing may be off. Review permissions in Health → your profile → Apps → Human Hydration.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !health.sleepEnabled {
                        Button("Include sleep") { Task { await health.connect(includeSleep: true) } }
                    } else {
                        Text("Sleep access requested").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Refresh") { Task { await health.refresh() } }
                        Spacer()
                        Button("Disconnect", role: .destructive) { health.disconnect() }
                    }
                } else {
                    Button { Task { await health.connect() } } label: {
                        HStack {
                            if health.busy { ProgressView() }
                            Text("Connect Apple Health").frame(maxWidth: .infinity)
                        }.padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).tint(.blue)
                }
            } else {
                Text("Apple Health isn’t available on this device.").font(.subheadline)
            }
            if let error = health.error { Text(error).font(.caption).foregroundStyle(.red) }
            Text("Optional. You choose what to share. Health data is processed on this device and isn’t sent to AI. Disconnecting stops access in this app; manage Apple permissions in Health.")
                .font(.caption).foregroundStyle(.secondary)
        }.disabled(health.busy)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }
}

struct HealthRoutineCard: View {
    @EnvironmentObject private var health: HealthKitService
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if health.enabled {
                Label("Your routine", systemImage: "sparkles").font(.title3)
                if let text = health.latestWorkoutText { Text(text).font(.subheadline) }
                Text(health.routineText).font(.subheadline)
                if let bedtime = health.bedtime {
                    Divider()
                    Text("Your latest recorded sleep began around \(bedtime.formatted(date: .omitted, time: .shortened)). Try an earlier evening log check-in so you don’t have to catch up at bedtime.")
                        .font(.subheadline)
                }
                Text("Based on available Health records. Workout history doesn’t measure fluid loss or change your daily goal.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = health.error { Text(error).font(.caption).foregroundStyle(.red) }
            } else {
                HealthConnectionCard()
            }
        }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(28)))
    }
}
