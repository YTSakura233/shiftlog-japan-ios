import Foundation
import UserNotifications

protocol NotificationProviding: Sendable {
    func requestAuthorization() async -> Bool
    func scheduleShiftReminder(shiftID: UUID, start: Date, isCancelled: Bool, jobName: String, minutesBefore: Int) async
    func cancelShiftReminder(shiftID: UUID) async
}

final class NotificationService: NotificationProviding, @unchecked Sendable {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleShiftReminder(shiftID: UUID, start: Date, isCancelled: Bool, jobName: String, minutesBefore: Int) async {
        guard start > Date(), !isCancelled else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.shift.title")
        content.body = String(format: String(localized: "notification.shift.body"), jobName, start.formatted(date: .omitted, time: .shortened))
        content.sound = .default
        let fireDate = start.addingTimeInterval(Double(-minutesBefore * 60))
        guard fireDate > Date() else { return }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(identifier: identifier(shiftID), content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try? await center.add(request)
    }

    func cancelShiftReminder(shiftID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(shiftID)])
    }

    private func identifier(_ id: UUID) -> String { "shift.\(id.uuidString)" }
}
