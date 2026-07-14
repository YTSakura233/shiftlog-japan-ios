import Foundation

struct ShiftInterval: Identifiable, Equatable, Sendable {
    let id: UUID
    let jobID: UUID
    let start: Date
    let end: Date
    let breakMinutes: Int
    let breaks: [BreakInterval]
    let isCancelled: Bool

    init(id: UUID, jobID: UUID, start: Date, end: Date, breakMinutes: Int, breaks: [BreakInterval] = [], isCancelled: Bool) {
        self.id = id; self.jobID = jobID; self.start = start; self.end = end
        self.breakMinutes = breakMinutes; self.breaks = breaks; self.isCancelled = isCancelled
    }

    var effectiveMinutes: Int {
        guard !isCancelled else { return 0 }
        return max(0, Int(end.timeIntervalSince(start) / 60) - breakMinutes)
    }

    func effectiveMinutes(overlapping range: DateInterval) -> Int {
        guard !isCancelled else { return 0 }
        let clippedStart = max(start, range.start), clippedEnd = min(end, range.end)
        guard clippedEnd > clippedStart else { return 0 }
        let total = Int(clippedEnd.timeIntervalSince(clippedStart) / 60)
        if !breaks.isEmpty {
            let clippedBreaks = breaks.reduce(0) { result, item in
                let breakStart = max(item.start, clippedStart), breakEnd = min(item.end, clippedEnd)
                return result + (breakEnd > breakStart ? Int(breakEnd.timeIntervalSince(breakStart) / 60) : 0)
            }
            return max(0, total - clippedBreaks)
        }
        let fullMinutes = max(1, Int(end.timeIntervalSince(start) / 60))
        let proportionalBreak = Int((Double(breakMinutes) * Double(total) / Double(fullMinutes)).rounded())
        return max(0, total - proportionalBreak)
    }
}

struct ShiftConflict: Equatable, Sendable {
    let proposedID: UUID
    let existingID: UUID
}

enum ConflictDetector {
    static func firstConflict(for proposed: ShiftInterval, among existing: [ShiftInterval]) -> ShiftConflict? {
        guard !proposed.isCancelled else { return nil }
        return existing.first(where: {
            $0.id != proposed.id && !$0.isCancelled && proposed.start < $0.end && proposed.end > $0.start
        }).map { ShiftConflict(proposedID: proposed.id, existingID: $0.id) }
    }
}

enum RiskLevel: Int, Comparable, Sendable {
    case safe, caution, warning, exceeded
    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct WorkRisk: Equatable, Sendable {
    let minutes: Int
    let limitMinutes: Int
    let level: RiskLevel
    var remainingMinutes: Int { max(0, limitMinutes - minutes) }
}

enum WorkLimitEngine {
    static func weeklyRisk(
        containing date: Date, shifts: [ShiftInterval], limitMinutes: Int,
        cautionMinutes: Int, warningMinutes: Int, weekStartDay: Int = 2,
        calendar baseCalendar: Calendar = .current
    ) -> WorkRisk {
        var calendar = baseCalendar
        calendar.firstWeekday = weekStartDay
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)!
        let total = shifts.reduce(0) { $0 + $1.effectiveMinutes(overlapping: interval) }
        return risk(minutes: total, limit: limitMinutes, caution: cautionMinutes, warning: warningMinutes)
    }

    static func rollingSevenDayRisk(
        endingAt date: Date, shifts: [ShiftInterval], limitMinutes: Int,
        cautionMinutes: Int, warningMinutes: Int, calendar: Calendar = .current
    ) -> WorkRisk {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        let interval = DateInterval(start: start, end: end)
        let total = shifts.reduce(0) { $0 + $1.effectiveMinutes(overlapping: interval) }
        return risk(minutes: total, limit: limitMinutes, caution: cautionMinutes, warning: warningMinutes)
    }

    private static func risk(minutes: Int, limit: Int, caution: Int, warning: Int) -> WorkRisk {
        let level: RiskLevel
        if minutes > limit { level = .exceeded }
        else if minutes >= warning { level = .warning }
        else if minutes >= caution { level = .caution }
        else { level = .safe }
        return WorkRisk(minutes: minutes, limitMinutes: limit, level: level)
    }
}

struct PayPeriod: Equatable, Sendable { let start: Date; let end: Date; let payDate: Date }

enum RecurrenceEditScope: String, CaseIterable, Identifiable, Sendable {
    case thisOccurrence, thisAndFuture, entireSeries
    var id: String { rawValue }
}

struct RecurrenceOccurrence: Equatable, Sendable {
    let id: UUID
    let start: Date
}

enum RecurrenceSeriesEngine {
    static func targetIDs(
        occurrences: [RecurrenceOccurrence],
        anchorID: UUID,
        scope: RecurrenceEditScope
    ) -> [UUID] {
        guard let anchor = occurrences.first(where: { $0.id == anchorID }) else { return [] }
        switch scope {
        case .thisOccurrence:
            return [anchorID]
        case .thisAndFuture:
            return occurrences.filter { $0.start >= anchor.start }.sorted { $0.start < $1.start }.map(\.id)
        case .entireSeries:
            return occurrences.sorted { $0.start < $1.start }.map(\.id)
        }
    }
}

enum PayPeriodEngine {
    static func monthly(containing date: Date, closingDay: Int, payDay: Int, calendar: Calendar = .current) -> PayPeriod {
        let day = calendar.component(.day, from: date)
        let anchor = day <= closingDay ? date : calendar.date(byAdding: .month, value: 1, to: date)!
        let components = calendar.dateComponents([.year, .month], from: anchor)
        let monthStart = calendar.date(from: components)!
        let endDay = min(closingDay, calendar.range(of: .day, in: .month, for: monthStart)!.count)
        let end = calendar.date(bySetting: .day, value: endDay, of: monthStart)!
        let previous = calendar.date(byAdding: .month, value: -1, to: monthStart)!
        let previousDays = calendar.range(of: .day, in: .month, for: previous)!.count
        let previousClose = calendar.date(bySetting: .day, value: min(closingDay, previousDays), of: previous)!
        let start = calendar.date(byAdding: .day, value: 1, to: previousClose)!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let payMonth = payDay <= endDay ? nextMonth : monthStart
        let payMonthDays = calendar.range(of: .day, in: .month, for: payMonth)!.count
        let payDate = calendar.date(bySetting: .day, value: min(payDay, payMonthDays), of: payMonth)!
        return PayPeriod(start: start, end: calendar.date(byAdding: .day, value: 1, to: end)!, payDate: payDate)
    }

    static func weekly(
        containing date: Date,
        intervalWeeks: Int = 1,
        weekStartDay: Int = 2,
        anchor: Date = Date(timeIntervalSince1970: 0),
        payWeekday: Int = 6,
        calendar baseCalendar: Calendar = .current
    ) -> PayPeriod {
        var calendar = baseCalendar
        calendar.firstWeekday = weekStartDay
        let weeks = max(1, intervalWeeks)
        let normalizedAnchor = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start
            ?? calendar.startOfDay(for: anchor)
        let targetWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        let dayDistance = calendar.dateComponents([.day], from: normalizedAnchor, to: targetWeek).day ?? 0
        let periodIndex = Int(floor(Double(dayDistance) / Double(7 * weeks)))
        let start = calendar.date(byAdding: .day, value: periodIndex * 7 * weeks, to: normalizedAnchor)!
        let end = calendar.date(byAdding: .day, value: 7 * weeks, to: start)!
        let payDate = nextWeekday(payWeekday, onOrAfter: end, calendar: calendar)
        return PayPeriod(start: start, end: end, payDate: payDate)
    }

    static func period(
        containing date: Date,
        kind: PayPeriodKind,
        closingDay: Int,
        payDay: Int,
        weekStartDay: Int,
        anchor: Date,
        payWeekday: Int,
        calendar: Calendar = .current
    ) -> PayPeriod {
        switch kind {
        case .monthly:
            monthly(containing: date, closingDay: closingDay, payDay: payDay, calendar: calendar)
        case .weekly:
            weekly(containing: date, weekStartDay: weekStartDay, anchor: anchor, payWeekday: payWeekday, calendar: calendar)
        case .biweekly:
            weekly(containing: date, intervalWeeks: 2, weekStartDay: weekStartDay, anchor: anchor, payWeekday: payWeekday, calendar: calendar)
        }
    }

    private static func nextWeekday(_ weekday: Int, onOrAfter date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        let current = calendar.component(.weekday, from: start)
        let offset = (min(7, max(1, weekday)) - current + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: start)!
    }
}
