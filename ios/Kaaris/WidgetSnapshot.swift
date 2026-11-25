import Foundation
import WidgetKit

enum WidgetSnapshot {
    private static let group = "group.com.kaariscoach.ios"
    private static let key = "kaaris.widget.snapshot.v1"
    private static let kind = "KaarisLockScreen"

    static func publish(sessions: [WorkoutSession], goal: Int, now: Date = .now, calendar: Calendar = .current) {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
              let shared = UserDefaults(suiteName: group) else { return }
        let snapshot = Snapshot(
            nextSessionAt: sessions.first { $0.status == .planned && $0.date > now }?.date,
            completedThisWeek: sessions.filter {
                $0.status == .completed && calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
            }.count,
            weeklyGoal: goal
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot), data != shared.data(forKey: key) else { return }
        shared.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    static func clear() {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
              let shared = UserDefaults(suiteName: group) else { return }
        shared.removeObject(forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    private struct Snapshot: Codable {
        let nextSessionAt: Date?
        let completedThisWeek: Int
        let weeklyGoal: Int
    }
}
