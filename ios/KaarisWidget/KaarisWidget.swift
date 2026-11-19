import SwiftUI
import WidgetKit

private struct WorkoutSnapshot: Codable {
    let nextSessionAt: Date?
    let completedThisWeek: Int
    let weeklyGoal: Int

    static func load() -> WorkoutSnapshot? {
        guard let data = UserDefaults(suiteName: "group.com.kaariscoach.ios")?.data(forKey: "kaaris.widget.snapshot.v1") else { return nil }
        return try? JSONDecoder().decode(WorkoutSnapshot.self, from: data)
    }
}

private struct WorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: WorkoutSnapshot?

    var nextSession: Date? {
        snapshot?.nextSessionAt.flatMap { $0 > date ? $0 : nil }
    }

    var progress: (completed: Int, goal: Int)? {
        guard let snapshot, (2...6).contains(snapshot.weeklyGoal) else { return nil }
        return (max(0, snapshot.completedThisWeek), snapshot.weeklyGoal)
    }
}

private struct WorkoutTimeline: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        let now = Date.now
        let snapshot = context.isPreview ? WorkoutSnapshot(
            nextSessionAt: now.addingTimeInterval(3600), completedThisWeek: 2, weeklyGoal: 4
        ) : WorkoutSnapshot.load()
        completion(WorkoutEntry(date: now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        let now = Date.now
        let snapshot = WorkoutSnapshot.load()
        let entry = WorkoutEntry(date: now, snapshot: snapshot)
        let refresh = now.addingTimeInterval(3600)

        var entries = [entry]
        if let nextSession = entry.nextSession, nextSession < refresh {
            entries.append(WorkoutEntry(date: nextSession, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

private struct WorkoutAccessory: View {
    @Environment(\.widgetFamily) private var family

    let entry: WorkoutEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                rectangular
            case .accessoryInline:
                inline
            default:
                fallback
            }
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .widgetURL(URL(string: "kaaris://checkin"))
        .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var circular: some View {
        if let progress = entry.progress {
            Gauge(value: Double(min(progress.completed, progress.goal)), in: 0...Double(progress.goal)) {
                Text("Séances")
            } currentValueLabel: {
                Text("\(progress.completed)/\(progress.goal)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
            }
            .gaugeStyle(.accessoryCircular)
            .accessibilityLabel("\(progress.completed) séances sur \(progress.goal) cette semaine")
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "bolt.fill")
                    .accessibilityLabel("Pointage KAARIS")
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("KAARIS", systemImage: "bolt.fill")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
            if let date = entry.nextSession {
                Text(date, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.headline)
                    .accessibilityLabel(Text("Prochaine séance, \(date.formatted(.dateTime.weekday(.wide).hour().minute()))"))
            } else {
                Text("Pointage séance").font(.headline)
            }
            if let progress = entry.progress {
                Text("\(progress.completed)/\(progress.goal) séances").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label {
            if let date = entry.nextSession {
                Text(date, format: .dateTime.weekday(.abbreviated).hour().minute())
            } else {
                Text("Pointage KAARIS")
            }
        } icon: {
            Image(systemName: "bolt.fill")
        }
    }

    private var fallback: some View {
        Label("Pointage KAARIS", systemImage: "bolt.fill")
    }
}

@main
struct KaarisWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KaarisLockScreen", provider: WorkoutTimeline()) { entry in
            WorkoutAccessory(entry: entry)
        }
        .configurationDisplayName("KAARIS")
        .description("Retrouve ta prochaine séance et ton pointage depuis l’écran verrouillé.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
