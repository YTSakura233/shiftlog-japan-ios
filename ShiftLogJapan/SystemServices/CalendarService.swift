import Foundation
import EventKit

enum CalendarSyncError: LocalizedError {
    case denied, calendarUnavailable
    var errorDescription: String? {
        switch self {
        case .denied: String(localized: "calendar.permission.denied")
        case .calendarUnavailable: String(localized: "calendar.unavailable")
        }
    }
}

@MainActor protocol CalendarSyncProviding {
    func requestAccess() async -> Bool
    func upsert(shift: Shift, job: Job) async throws -> String
    func delete(eventIdentifier: String) throws
}

@MainActor final class CalendarService: CalendarSyncProviding {
    static let shared = CalendarService()
    private let store = EKEventStore()
    private init() {}

    func requestAccess() async -> Bool { (try? await store.requestFullAccessToEvents()) ?? false }

    func upsert(shift: Shift, job: Job) async throws -> String {
        guard await requestAccess() else { throw CalendarSyncError.denied }
        let calendar = try appCalendar()
        let event = shift.calendarEventID.flatMap(store.event(withIdentifier:)) ?? EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = job.displayName
        event.location = [job.locationName, job.address].filter { !$0.isEmpty }.joined(separator: " · ")
        event.startDate = shift.scheduledStart; event.endDate = shift.scheduledEnd
        event.notes = shift.notes
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    func delete(eventIdentifier: String) throws {
        guard let event = store.event(withIdentifier: eventIdentifier), event.calendar.title == AppConfiguration.calendarTitle else { return }
        try store.remove(event, span: .thisEvent, commit: true)
    }

    private func appCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == AppConfiguration.calendarTitle }) { return existing }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = AppConfiguration.calendarTitle
        calendar.source = store.defaultCalendarForNewEvents?.source ?? store.sources.first { $0.sourceType == .local }
        guard calendar.source != nil else { throw CalendarSyncError.calendarUnavailable }
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }
}
