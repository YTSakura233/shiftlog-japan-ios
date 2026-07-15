import Foundation

enum ShiftDateLinker {
    static func defaultRange(
        for day: Date,
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day) ?? day
        let sameDayEnd = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: day)
            ?? start.addingTimeInterval(8 * 3_600)
        let end = sameDayEnd <= start
            ? calendar.date(byAdding: .day, value: 1, to: sameDayEnd) ?? sameDayEnd
            : sameDayEnd
        return (start, end)
    }

    static func replacingDay(of value: Date, with day: Date, calendar: Calendar = .current) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: value)
        var components = calendar.dateComponents([.era, .year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        components.nanosecond = time.nanosecond
        return calendar.date(from: components) ?? value
    }

    static func afterStartChange(start: Date, end: Date, crossDayEnabled: Bool, calendar: Calendar = .current) -> (start: Date, end: Date) {
        guard !crossDayEnabled else { return (start, end) }
        return (start, replacingDay(of: end, with: start, calendar: calendar))
    }

    static func afterEndChange(start: Date, end: Date, crossDayEnabled: Bool, calendar: Calendar = .current) -> (start: Date, end: Date) {
        guard !crossDayEnabled else { return (start, end) }
        return (replacingDay(of: start, with: end, calendar: calendar), end)
    }

    static func disablingCrossDay(start: Date, end: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        (start, replacingDay(of: end, with: start, calendar: calendar))
    }

    static func promoteEndToNextDay(start: Date, end: Date, calendar: Calendar = .current) -> Date {
        let sameDayEnd = replacingDay(of: end, with: start, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: sameDayEnd) ?? sameDayEnd
    }
}
