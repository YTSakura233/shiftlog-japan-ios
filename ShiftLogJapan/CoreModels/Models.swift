import Foundation
import SwiftData

enum ShiftStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled, completed, cancelled, absent
    var id: String { rawValue }
    var titleKey: String { "shift.status.\(rawValue)" }
    var localizedTitle: String {
        localizedTitle(locale: .current)
    }
    func localizedTitle(locale: Locale) -> String {
        switch self {
        case .scheduled: String(localized: "shift.status.scheduled", defaultValue: "Scheduled", locale: locale)
        case .completed: String(localized: "shift.status.completed", defaultValue: "Completed", locale: locale)
        case .cancelled: String(localized: "shift.status.cancelled", defaultValue: "Cancelled", locale: locale)
        case .absent: String(localized: "shift.status.absent", defaultValue: "Absent", locale: locale)
        }
    }
}

enum PremiumKind: String, Codable, CaseIterable { case timeRange, weekday, specificDate }
enum RoundingDirection: String, Codable, CaseIterable { case down, nearest, up }
enum TransportKind: String, Codable, CaseIterable, Identifiable {
    case none, perShift, manual
    var id: String { rawValue }
}

enum PayPeriodKind: String, Codable, CaseIterable, Identifiable {
    case monthly, weekly, biweekly
    var id: String { rawValue }
}

@Model final class UserSettings {
    var id: UUID = UUID()
    var localeCode: String = "zh-Hans"
    var currencyCode: String = "JPY"
    var weekStartDay: Int = 2
    var workLimitEnabled: Bool = true
    var weeklyLimitMinutes: Int = 1_680
    var rollingSevenDayCheckEnabled: Bool = true
    var cautionMinutes: Int = 1_440
    var warningMinutes: Int = 1_560
    var disclaimerAcceptedAt: Date?
    var onboardingCompleted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}
}

@Model final class Job {
    var id: UUID = UUID()
    var displayName: String = ""
    var employerName: String = ""
    var locationName: String = ""
    var address: String = ""
    var prefectureCode: String = ""
    var colorHex: String = "5B7DB1"
    var defaultStartHour: Int = 9
    var defaultStartMinute: Int = 0
    var defaultEndHour: Int = 17
    var defaultEndMinute: Int = 0
    var defaultBreakMinutes: Int = 60
    var transportKindRaw: String = TransportKind.none.rawValue
    var transportAmount: Decimal = 0
    var roundingIntervalMinutes: Int = 1
    var roundingDirectionRaw: String = RoundingDirection.nearest.rawValue
    var wageRoundingUnit: Int = 1
    var payClosingDay: Int = 31
    var payDay: Int = 25
    var payPeriodKindRaw: String = PayPeriodKind.monthly.rawValue
    var payWeekStartDay: Int = 2
    var payWeekday: Int = 6
    var payPeriodAnchor: Date = Date(timeIntervalSince1970: 0)
    var payReminderEnabled: Bool = false
    var payReminderDaysBefore: Int = 1
    var shiftReminderMinutes: Int = 60
    var shiftEndReminderEnabled: Bool = true
    var calendarSyncEnabled: Bool = false
    var notes: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(displayName: String, employerName: String = "", hourlyAmount: Decimal = 0, colorHex: String = "5B7DB1") {
        self.displayName = displayName
        self.employerName = employerName
        self.colorHex = colorHex
    }

    var transportKind: TransportKind { TransportKind(rawValue: transportKindRaw) ?? .none }
    var roundingDirection: RoundingDirection { RoundingDirection(rawValue: roundingDirectionRaw) ?? .nearest }
    var payPeriodKind: PayPeriodKind { PayPeriodKind(rawValue: payPeriodKindRaw) ?? .monthly }
}

@Model final class WageRate {
    var id: UUID = UUID()
    var jobID: UUID = UUID()
    var hourlyAmount: Decimal = 0
    var effectiveFrom: Date = Date.distantPast
    var effectiveTo: Date?
    var createdAt: Date = Date()

    init(jobID: UUID, hourlyAmount: Decimal, effectiveFrom: Date = Date.distantPast) {
        self.jobID = jobID
        self.hourlyAmount = hourlyAmount
        self.effectiveFrom = effectiveFrom
    }
}

@Model final class PremiumRule {
    var id: UUID = UUID()
    var jobID: UUID = UUID()
    var name: String = ""
    var kindRaw: String = PremiumKind.timeRange.rawValue
    var startMinutesFromMidnight: Int = 1_320
    var endMinutesFromMidnight: Int = 300
    var weekdaysCSV: String = ""
    var specificDate: Date?
    var percentage: Decimal = 0
    var fixedHourlyAmount: Decimal = 0
    var fixedShiftAmount: Decimal = 0
    var stackable: Bool = true
    var priority: Int = 0
    var effectiveFrom: Date = Date.distantPast
    var effectiveTo: Date?
    var enabled: Bool = true

    init(jobID: UUID, name: String, percentage: Decimal = 0) {
        self.jobID = jobID
        self.name = name
        self.percentage = percentage
    }

    var kind: PremiumKind { PremiumKind(rawValue: kindRaw) ?? .timeRange }
}

@Model final class Shift {
    var id: UUID = UUID()
    var jobID: UUID = UUID()
    var statusRaw: String = ShiftStatus.scheduled.rawValue
    var scheduledStart: Date = Date()
    var scheduledEnd: Date = Date().addingTimeInterval(8 * 3_600)
    var actualStart: Date?
    var actualEnd: Date?
    var actualConfirmed: Bool = false
    var transportAmount: Decimal = 0
    var bonusAmount: Decimal = 0
    var deductionAmount: Decimal = 0
    var notes: String = ""
    var recurrenceSeriesID: UUID?
    var calendarEventID: String?
    var timeZoneIdentifier: String = TimeZone.current.identifier
    var snapshotHourlyRate: Decimal?
    var snapshotBaseWage: Decimal?
    var snapshotPremiumWage: Decimal?
    var snapshotTotal: Decimal?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false

    init(jobID: UUID, scheduledStart: Date, scheduledEnd: Date, status: ShiftStatus = .scheduled) {
        self.jobID = jobID
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.statusRaw = status.rawValue
    }

    var status: ShiftStatus {
        get { ShiftStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }
}

@Model final class ShiftBreak {
    var id: UUID = UUID()
    var shiftID: UUID = UUID()
    var isActual: Bool = false
    var start: Date = Date()
    var end: Date = Date()

    init(shiftID: UUID, isActual: Bool, start: Date, end: Date) {
        self.shiftID = shiftID
        self.isActual = isActual
        self.start = start
        self.end = end
    }
}

@Model final class Payment {
    var id: UUID = UUID()
    var jobID: UUID = UUID()
    var periodStart: Date = Date()
    var periodEnd: Date = Date()
    var estimatedLabor: Decimal = 0
    var grossAmount: Decimal?
    var deductions: Decimal = 0
    var incomeTax: Decimal = 0
    var employmentInsurance: Decimal = 0
    var healthInsurance: Decimal = 0
    var pension: Decimal = 0
    var residentTax: Decimal = 0
    var otherDeductions: Decimal = 0
    var transportAmount: Decimal = 0
    var receivedAmount: Decimal?
    var receivedDate: Date?
    var notes: String = ""
    var includedShiftIDsCSV: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(jobID: UUID, periodStart: Date, periodEnd: Date) {
        self.jobID = jobID
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }
    var includedShiftIDs: [UUID] {
        includedShiftIDsCSV.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }
}
