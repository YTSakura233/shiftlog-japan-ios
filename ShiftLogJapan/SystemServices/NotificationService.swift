import Foundation
import UserNotifications

protocol NotificationProviding: Sendable {
    func requestAuthorization() async -> Bool
    func scheduleShiftReminder(shiftID: UUID, start: Date, isCancelled: Bool, jobName: String, minutesBefore: Int) async
    func scheduleShiftEndConfirmation(shiftID: UUID, end: Date, isCancelled: Bool, jobName: String, enabled: Bool) async
    func schedulePayReminder(jobID: UUID, payDate: Date, jobName: String, daysBefore: Int, enabled: Bool) async
    func cancelShiftReminder(shiftID: UUID) async
    func cancelPayReminder(jobID: UUID) async
    func scheduleCredentialReminders(reminderID: UUID, dueDate: Date, daysBefore: [Int], title: String, enabled: Bool) async
    func cancelCredentialReminders(reminderID: UUID) async
}

final class NotificationService: NotificationProviding, @unchecked Sendable {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleShiftReminder(shiftID: UUID, start: Date, isCancelled: Bool, jobName: String, minutesBefore: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [legacyShiftIdentifier(shiftID), shiftStartIdentifier(shiftID)])
        guard start > Date(), !isCancelled else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.shift.title")
        content.body = String(format: String(localized: "notification.shift.body"), jobName, start.formatted(date: .omitted, time: .shortened))
        content.sound = .default
        let fireDate = start.addingTimeInterval(Double(-minutesBefore * 60))
        guard fireDate > Date() else { return }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(identifier: shiftStartIdentifier(shiftID), content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try? await center.add(request)
    }

    func scheduleShiftEndConfirmation(shiftID: UUID, end: Date, isCancelled: Bool, jobName: String, enabled: Bool) async {
        center.removePendingNotificationRequests(withIdentifiers: [shiftEndIdentifier(shiftID)])
        guard enabled, !isCancelled, end > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.shiftEnd.title")
        content.body = String(format: String(localized: "notification.shiftEnd.body"), jobName)
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: end)
        let request = UNNotificationRequest(identifier: shiftEndIdentifier(shiftID), content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try? await center.add(request)
    }

    func schedulePayReminder(jobID: UUID, payDate: Date, jobName: String, daysBefore: Int, enabled: Bool) async {
        await cancelPayReminder(jobID: jobID)
        guard enabled else { return }
        let fireDate = Calendar.current.date(byAdding: .day, value: -max(0, daysBefore), to: payDate) ?? payDate
        guard fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.pay.title")
        content.body = String(format: String(localized: "notification.pay.body"), jobName, payDate.formatted(date: .abbreviated, time: .omitted))
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        let request = UNNotificationRequest(identifier: payIdentifier(jobID), content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try? await center.add(request)
    }

    func cancelShiftReminder(shiftID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [legacyShiftIdentifier(shiftID), shiftStartIdentifier(shiftID), shiftEndIdentifier(shiftID)])
    }

    func cancelPayReminder(jobID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [payIdentifier(jobID)])
    }

    func scheduleCredentialReminders(reminderID: UUID, dueDate: Date, daysBefore: [Int], title: String, enabled: Bool) async {
        await cancelCredentialReminders(reminderID: reminderID)
        guard enabled else { return }
        for item in CredentialScheduleBuilder.futureFireDates(dueDate: dueDate, reminderDays: daysBefore) {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.credential.title")
            content.body = String(format: String(localized: "notification.credential.body"), title, item.daysBefore)
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let request = UNNotificationRequest(identifier: credentialIdentifier(reminderID, item.daysBefore), content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }

    func cancelCredentialReminders(reminderID: UUID) async {
        let prefix = "credential.\(reminderID.uuidString)."
        let identifiers = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func legacyShiftIdentifier(_ id: UUID) -> String { "shift.\(id.uuidString)" }
    private func shiftStartIdentifier(_ id: UUID) -> String { "shift.start.\(id.uuidString)" }
    private func shiftEndIdentifier(_ id: UUID) -> String { "shift.end.\(id.uuidString)" }
    private func payIdentifier(_ id: UUID) -> String { "pay.\(id.uuidString)" }
    private func credentialIdentifier(_ id: UUID, _ days: Int) -> String { "credential.\(id.uuidString).\(days)" }
}
