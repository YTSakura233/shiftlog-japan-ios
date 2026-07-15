import Foundation

enum CredentialScheduleBuilder {
    static func futureFireDates(dueDate: Date, reminderDays: [Int], now: Date = Date(), calendar: Calendar = .current) -> [(daysBefore: Int, date: Date)] {
        reminderDays.sorted(by: >).compactMap { days in
            guard let rawDate = calendar.date(byAdding: .day, value: -days, to: dueDate),
                  let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: rawDate),
                  date > now else { return nil }
            return (days, date)
        }
    }
}
