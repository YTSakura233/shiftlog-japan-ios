import Foundation

struct BreakInterval: Codable, Equatable, Sendable {
    let start: Date
    let end: Date
}

struct PremiumSpec: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let startMinutesFromMidnight: Int
    let endMinutesFromMidnight: Int
    let weekdays: Set<Int>
    let specificDate: Date?
    let percentage: Decimal
    let fixedHourlyAmount: Decimal
    let fixedShiftAmount: Decimal
    let stackable: Bool
    let priority: Int

    init(
        id: UUID = UUID(), name: String, startMinutesFromMidnight: Int = 0,
        endMinutesFromMidnight: Int = 1_440, weekdays: Set<Int> = [],
        specificDate: Date? = nil, percentage: Decimal = 0,
        fixedHourlyAmount: Decimal = 0, fixedShiftAmount: Decimal = 0,
        stackable: Bool = true, priority: Int = 0
    ) {
        self.id = id; self.name = name
        self.startMinutesFromMidnight = startMinutesFromMidnight
        self.endMinutesFromMidnight = endMinutesFromMidnight
        self.weekdays = weekdays; self.specificDate = specificDate
        self.percentage = percentage; self.fixedHourlyAmount = fixedHourlyAmount
        self.fixedShiftAmount = fixedShiftAmount; self.stackable = stackable; self.priority = priority
    }
}

struct WageCalculation: Equatable, Sendable {
    let rawMinutes: Int
    let effectiveMinutes: Int
    let baseWage: Decimal
    let premiumWage: Decimal
    let transport: Decimal
    let total: Decimal
    let premiumMinutes: [String: Int]
    let appliedRuleNames: [String]
}

enum CalculationError: LocalizedError, Equatable {
    case endNotAfterStart
    case shiftTooLong
    case breakOutsideShift
    case overlappingBreaks

    var errorDescription: String? {
        switch self {
        case .endNotAfterStart: return String(localized: "error.shift.end")
        case .shiftTooLong: return String(localized: "error.shift.tooLong")
        case .breakOutsideShift: return String(localized: "error.break.outside")
        case .overlappingBreaks: return String(localized: "error.break.overlap")
        }
    }
}

enum CalculationEngine {
    static func validate(start: Date, end: Date, breaks: [BreakInterval], maximumHours: Int = 24) throws {
        guard end > start else { throw CalculationError.endNotAfterStart }
        guard end.timeIntervalSince(start) <= Double(maximumHours * 3_600) else { throw CalculationError.shiftTooLong }
        let sorted = breaks.sorted { $0.start < $1.start }
        for item in sorted {
            guard item.start >= start, item.end <= end, item.end > item.start else { throw CalculationError.breakOutsideShift }
        }
        for pair in zip(sorted, sorted.dropFirst()) where pair.0.end > pair.1.start {
            throw CalculationError.overlappingBreaks
        }
    }

    static func effectiveMinutes(start: Date, end: Date, breaks: [BreakInterval]) throws -> Int {
        try validate(start: start, end: end, breaks: breaks)
        let total = Int(end.timeIntervalSince(start) / 60)
        let breakMinutes = breaks.reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
        return max(0, total - breakMinutes)
    }

    static func calculate(
        start: Date, end: Date, breaks: [BreakInterval], hourlyRate: Decimal,
        premiums: [PremiumSpec], transport: Decimal = 0, bonus: Decimal = 0,
        deduction: Decimal = 0, roundingInterval: Int = 1,
        roundingDirection: RoundingDirection = .nearest, wageRoundingUnit: Int = 1,
        calendar: Calendar = .current
    ) throws -> WageCalculation {
        try validate(start: start, end: end, breaks: breaks)
        let rawMinutes = try effectiveMinutes(start: start, end: end, breaks: breaks)
        let roundedMinutes = round(minutes: rawMinutes, interval: roundingInterval, direction: roundingDirection)
        let minuteRate = hourlyRate / 60
        let base = minuteRate * Decimal(roundedMinutes)
        var premium = Decimal.zero
        var counts: [String: Int] = [:]
        var rulesApplied = Set<String>()
        var fixedShiftApplied = Set<UUID>()

        var cursor = start
        while cursor < end {
            let next = min(cursor.addingTimeInterval(60), end)
            if next.timeIntervalSince(cursor) >= 59.9, !isBreakMinute(cursor, breaks: breaks) {
                let matchingRules = premiums.filter { Self.matches($0, at: cursor, calendar: calendar) }
                let stackable = matchingRules.filter { $0.stackable }
                let exclusive = matchingRules.filter { !$0.stackable }.max { $0.priority < $1.priority }
                let applied = stackable + (exclusive.map { [$0] } ?? [])
                for rule in applied {
                    premium += minuteRate * rule.percentage
                    premium += rule.fixedHourlyAmount / 60
                    counts[rule.name, default: 0] += 1
                    rulesApplied.insert(rule.name)
                    if rule.fixedShiftAmount != 0, fixedShiftApplied.insert(rule.id).inserted {
                        premium += rule.fixedShiftAmount
                    }
                }
            }
            cursor = next
        }

        let roundedBase = roundMoney(base, unit: wageRoundingUnit)
        let roundedPremium = roundMoney(premium, unit: wageRoundingUnit)
        let total = roundMoney(roundedBase + roundedPremium + bonus - deduction + transport, unit: wageRoundingUnit)
        return WageCalculation(
            rawMinutes: rawMinutes, effectiveMinutes: roundedMinutes,
            baseWage: roundedBase, premiumWage: roundedPremium,
            transport: transport, total: total,
            premiumMinutes: counts, appliedRuleNames: rulesApplied.sorted()
        )
    }

    static func round(minutes: Int, interval: Int, direction: RoundingDirection) -> Int {
        guard interval > 1 else { return minutes }
        let value = Decimal(minutes) / Decimal(interval)
        let mode: Decimal.RoundingMode = switch direction {
        case .down: .down
        case .nearest: .plain
        case .up: .up
        }
        var rounded = Decimal.zero
        var source = value
        NSDecimalRound(&rounded, &source, 0, mode)
        return NSDecimalNumber(decimal: rounded * Decimal(interval)).intValue
    }

    static func roundMoney(_ amount: Decimal, unit: Int) -> Decimal {
        guard unit > 1 else {
            var rounded = Decimal.zero, source = amount
            NSDecimalRound(&rounded, &source, 0, .plain)
            return rounded
        }
        var quotient = amount / Decimal(unit)
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &quotient, 0, .plain)
        return rounded * Decimal(unit)
    }

    private static func isBreakMinute(_ date: Date, breaks: [BreakInterval]) -> Bool {
        breaks.contains { date >= $0.start && date < $0.end }
    }

    private static func matches(_ rule: PremiumSpec, at date: Date, calendar: Calendar) -> Bool {
        if let specific = rule.specificDate, !calendar.isDate(date, inSameDayAs: specific) { return false }
        let weekday = calendar.component(.weekday, from: date)
        if !rule.weekdays.isEmpty, !rule.weekdays.contains(weekday) { return false }
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let start = rule.startMinutesFromMidnight
        let end = rule.endMinutesFromMidnight
        if start == end || (start == 0 && end == 1_440) { return true }
        return start < end ? (minute >= start && minute < end) : (minute >= start || minute < end)
    }
}
