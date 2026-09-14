import SwiftUI

struct RoutineDay: Identifiable {
    let date: Date
    let workoutMinutes: Int
    var id: Date { date }
}

struct RoutineWeekChart: View {
    let days: [RoutineDay]

    private var activeDays: Int { days.filter { $0.workoutMinutes > 0 }.count }
    private var averageMinutes: Int {
        let active = days.filter { $0.workoutMinutes > 0 }
        return active.isEmpty ? 0 : active.reduce(0) { $0 + $1.workoutMinutes } / active.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly rhythm").font(.headline.weight(.regular))
                    Text("Last 7 days").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if activeDays > 0 {
                    Text("\(activeDays) days · ~\(averageMinutes) min")
                        .font(.caption.weight(.medium)).foregroundStyle(.blue)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    VStack(spacing: 7) {
                        Text(day.workoutMinutes > 0 ? "\(day.workoutMinutes)" : "")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(height: 12)
                        ZStack(alignment: .bottom) {
                            Capsule().fill(Color.blue.opacity(0.08)).frame(height: 76)
                            if day.workoutMinutes > 0 {
                                Capsule()
                                    .fill(LinearGradient(colors: [Color.cyan.opacity(0.65), Color.blue], startPoint: .bottom, endPoint: .top))
                                    .frame(height: max(20, 76 * min(Double(day.workoutMinutes) / 90, 1)))
                            }
                        }
                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(Calendar.current.isDateInToday(day.date) ? .bold : .regular))
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.primary : Color.secondary)
                    }.frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide))), \(day.workoutMinutes) workout minutes")
                }
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel("Workout routine over the last seven days")
    }
}

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
                RoutineWeekChart(days: routineDays)
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

    private var routineDays: [RoutineDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let minutesByDay = Dictionary(grouping: health.workouts, by: { calendar.startOfDay(for: $0.startDate) })
            .mapValues { workouts in Int(workouts.reduce(0) { $0 + $1.duration } / 60) }
        return (-6...0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            return RoutineDay(date: date, workoutMinutes: minutesByDay[date, default: 0])
        }
    }
}
