import Foundation

enum ModelAdapters {
    static func wageRate(for jobID: UUID, on date: Date, rates: [WageRate]) -> Decimal {
        rates.filter { $0.jobID == jobID && $0.effectiveFrom <= date && ($0.effectiveTo == nil || $0.effectiveTo! > date) }
            .sorted { $0.effectiveFrom > $1.effectiveFrom }.first?.hourlyAmount ?? 0
    }

    static func premiumSpecs(for jobID: UUID, on date: Date, rules: [PremiumRule]) -> [PremiumSpec] {
        rules.filter { $0.jobID == jobID && $0.enabled && $0.effectiveFrom <= date && ($0.effectiveTo == nil || $0.effectiveTo! > date) }.map {
            PremiumSpec(
                id: $0.id, name: $0.name, startMinutesFromMidnight: $0.startMinutesFromMidnight,
                endMinutesFromMidnight: $0.endMinutesFromMidnight,
                weekdays: Set($0.weekdaysCSV.split(separator: ",").compactMap { Int($0) }),
                specificDate: $0.specificDate, percentage: $0.percentage,
                fixedHourlyAmount: $0.fixedHourlyAmount, fixedShiftAmount: $0.fixedShiftAmount,
                stackable: $0.stackable, priority: $0.priority
            )
        }
    }

    static func breaks(for shiftID: UUID, actual: Bool, all: [ShiftBreak]) -> [BreakInterval] {
        all.filter { $0.shiftID == shiftID && $0.isActual == actual }.map { BreakInterval(start: $0.start, end: $0.end) }
    }
}
