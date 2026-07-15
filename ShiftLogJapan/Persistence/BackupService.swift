import Foundation

struct BackupPayload: Codable {
    var version = 3
    var createdAt = Date()
    var settings: [SettingsRecord]
    var jobs: [JobRecord]
    var rates: [WageRateRecord]
    var premiumRules: [PremiumRecord]
    var shifts: [ShiftRecord]
    var breaks: [BreakRecord]
    var payments: [PaymentRecord]
    var documents: [DocumentRecord]? = nil
    var credentialReminders: [CredentialReminderRecord]? = nil
}

struct SettingsRecord: Codable {
    let id: UUID; let localeCode: String; let weekStartDay: Int; let workLimitEnabled: Bool
    let weeklyLimitMinutes: Int; let rollingSevenDayCheckEnabled: Bool; let cautionMinutes: Int
    let warningMinutes: Int; let disclaimerAcceptedAt: Date?; let onboardingCompleted: Bool
    let biometricLockEnabled: Bool?
}

struct JobRecord: Codable {
    let id: UUID; let displayName, employerName, locationName, address, prefectureCode, colorHex: String
    let defaultStartHour, defaultStartMinute, defaultEndHour, defaultEndMinute, defaultBreakMinutes: Int
    let transportKindRaw: String; let transportAmount: Decimal; let roundingIntervalMinutes: Int
    let roundingDirectionRaw: String; let wageRoundingUnit, payClosingDay, payDay, shiftReminderMinutes: Int
    let calendarSyncEnabled: Bool; let notes: String; let isActive: Bool; let createdAt, updatedAt: Date
    let payPeriodKindRaw: String?; let payWeekStartDay, payWeekday: Int?; let payPeriodAnchor: Date?
    let payReminderEnabled: Bool?; let payReminderDaysBefore: Int?; let shiftEndReminderEnabled: Bool?
}

struct WageRateRecord: Codable { let id, jobID: UUID; let hourlyAmount: Decimal; let effectiveFrom: Date; let effectiveTo: Date? }
struct PremiumRecord: Codable {
    let id, jobID: UUID; let name, kindRaw: String; let startMinutesFromMidnight, endMinutesFromMidnight: Int
    let weekdaysCSV: String; let specificDate: Date?; let percentage, fixedHourlyAmount, fixedShiftAmount: Decimal
    let stackable: Bool; let priority: Int; let effectiveFrom: Date; let effectiveTo: Date?; let enabled: Bool
}
struct ShiftRecord: Codable {
    let id, jobID: UUID; let statusRaw: String; let scheduledStart, scheduledEnd: Date
    let actualStart, actualEnd: Date?; let actualConfirmed: Bool; let transportAmount, bonusAmount, deductionAmount: Decimal
    let notes: String; let recurrenceSeriesID: UUID?; let timeZoneIdentifier: String
    let snapshotHourlyRate, snapshotBaseWage, snapshotPremiumWage, snapshotTotal: Decimal?
    let createdAt, updatedAt: Date; let isDeleted: Bool
}
struct BreakRecord: Codable { let id, shiftID: UUID; let isActual: Bool; let start, end: Date }
struct PaymentRecord: Codable {
    let id, jobID: UUID; let periodStart, periodEnd: Date; let estimatedLabor: Decimal; let grossAmount: Decimal?
    let deductions, transportAmount: Decimal; let receivedAmount: Decimal?; let receivedDate: Date?; let notes: String
    let incomeTax, employmentInsurance, healthInsurance, pension, residentTax, otherDeductions: Decimal?
    let includedShiftIDsCSV: String?
}
struct DocumentRecord: Codable {
    let id: UUID; let jobID, paymentID: UUID?; let typeRaw, originalFileName, contentTypeIdentifier: String
    let fileSize: Int64; let recognizedText: String; let createdAt, updatedAt: Date; let fileData: Data?
}
struct CredentialReminderRecord: Codable {
    let id: UUID; let typeRaw: String; let dueDate: Date; let reminderDaysCSV, notes: String
    let enabled: Bool; let createdAt, updatedAt: Date
}

enum BackupService {
    static func encode(settings: [UserSettings], jobs: [Job], rates: [WageRate], rules: [PremiumRule], shifts: [Shift], breaks: [ShiftBreak], payments: [Payment], documents: [EmploymentDocument] = [], credentialReminders: [CredentialReminder] = []) throws -> Data {
        let payload = BackupPayload(
            settings: settings.map { SettingsRecord(id: $0.id, localeCode: $0.localeCode, weekStartDay: $0.weekStartDay, workLimitEnabled: $0.workLimitEnabled, weeklyLimitMinutes: $0.weeklyLimitMinutes, rollingSevenDayCheckEnabled: $0.rollingSevenDayCheckEnabled, cautionMinutes: $0.cautionMinutes, warningMinutes: $0.warningMinutes, disclaimerAcceptedAt: $0.disclaimerAcceptedAt, onboardingCompleted: $0.onboardingCompleted, biometricLockEnabled: $0.biometricLockEnabled) },
            jobs: jobs.map { JobRecord(id: $0.id, displayName: $0.displayName, employerName: $0.employerName, locationName: $0.locationName, address: $0.address, prefectureCode: $0.prefectureCode, colorHex: $0.colorHex, defaultStartHour: $0.defaultStartHour, defaultStartMinute: $0.defaultStartMinute, defaultEndHour: $0.defaultEndHour, defaultEndMinute: $0.defaultEndMinute, defaultBreakMinutes: $0.defaultBreakMinutes, transportKindRaw: $0.transportKindRaw, transportAmount: $0.transportAmount, roundingIntervalMinutes: $0.roundingIntervalMinutes, roundingDirectionRaw: $0.roundingDirectionRaw, wageRoundingUnit: $0.wageRoundingUnit, payClosingDay: $0.payClosingDay, payDay: $0.payDay, shiftReminderMinutes: $0.shiftReminderMinutes, calendarSyncEnabled: $0.calendarSyncEnabled, notes: $0.notes, isActive: $0.isActive, createdAt: $0.createdAt, updatedAt: $0.updatedAt, payPeriodKindRaw: $0.payPeriodKindRaw, payWeekStartDay: $0.payWeekStartDay, payWeekday: $0.payWeekday, payPeriodAnchor: $0.payPeriodAnchor, payReminderEnabled: $0.payReminderEnabled, payReminderDaysBefore: $0.payReminderDaysBefore, shiftEndReminderEnabled: $0.shiftEndReminderEnabled) },
            rates: rates.map { WageRateRecord(id: $0.id, jobID: $0.jobID, hourlyAmount: $0.hourlyAmount, effectiveFrom: $0.effectiveFrom, effectiveTo: $0.effectiveTo) },
            premiumRules: rules.map { PremiumRecord(id: $0.id, jobID: $0.jobID, name: $0.name, kindRaw: $0.kindRaw, startMinutesFromMidnight: $0.startMinutesFromMidnight, endMinutesFromMidnight: $0.endMinutesFromMidnight, weekdaysCSV: $0.weekdaysCSV, specificDate: $0.specificDate, percentage: $0.percentage, fixedHourlyAmount: $0.fixedHourlyAmount, fixedShiftAmount: $0.fixedShiftAmount, stackable: $0.stackable, priority: $0.priority, effectiveFrom: $0.effectiveFrom, effectiveTo: $0.effectiveTo, enabled: $0.enabled) },
            shifts: shifts.map { ShiftRecord(id: $0.id, jobID: $0.jobID, statusRaw: $0.statusRaw, scheduledStart: $0.scheduledStart, scheduledEnd: $0.scheduledEnd, actualStart: $0.actualStart, actualEnd: $0.actualEnd, actualConfirmed: $0.actualConfirmed, transportAmount: $0.transportAmount, bonusAmount: $0.bonusAmount, deductionAmount: $0.deductionAmount, notes: $0.notes, recurrenceSeriesID: $0.recurrenceSeriesID, timeZoneIdentifier: $0.timeZoneIdentifier, snapshotHourlyRate: $0.snapshotHourlyRate, snapshotBaseWage: $0.snapshotBaseWage, snapshotPremiumWage: $0.snapshotPremiumWage, snapshotTotal: $0.snapshotTotal, createdAt: $0.createdAt, updatedAt: $0.updatedAt, isDeleted: $0.isDeleted) },
            breaks: breaks.map { BreakRecord(id: $0.id, shiftID: $0.shiftID, isActual: $0.isActual, start: $0.start, end: $0.end) },
            payments: payments.map { PaymentRecord(id: $0.id, jobID: $0.jobID, periodStart: $0.periodStart, periodEnd: $0.periodEnd, estimatedLabor: $0.estimatedLabor, grossAmount: $0.grossAmount, deductions: $0.deductions, transportAmount: $0.transportAmount, receivedAmount: $0.receivedAmount, receivedDate: $0.receivedDate, notes: $0.notes, incomeTax: $0.incomeTax, employmentInsurance: $0.employmentInsurance, healthInsurance: $0.healthInsurance, pension: $0.pension, residentTax: $0.residentTax, otherDeductions: $0.otherDeductions, includedShiftIDsCSV: $0.includedShiftIDsCSV) },
            documents: documents.map { document in
                DocumentRecord(
                    id: document.id, jobID: document.jobID, paymentID: document.paymentID, typeRaw: document.typeRaw,
                    originalFileName: document.originalFileName, contentTypeIdentifier: document.contentTypeIdentifier,
                    fileSize: document.fileSize, recognizedText: document.recognizedText, createdAt: document.createdAt, updatedAt: document.updatedAt,
                    fileData: (try? DocumentFileStore.url(for: document.localFileName)).flatMap { try? Data(contentsOf: $0) }
                )
            },
            credentialReminders: credentialReminders.map { CredentialReminderRecord(id: $0.id, typeRaw: $0.typeRaw, dueDate: $0.dueDate, reminderDaysCSV: $0.reminderDaysCSV, notes: $0.notes, enabled: $0.enabled, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func decode(_ data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupPayload.self, from: data)
    }

    static func csv(jobs: [Job], shifts: [Shift], breaks: [ShiftBreak]) -> Data {
        let header = "Date,Job,Scheduled Start,Scheduled End,Actual Start,Actual End,Break Minutes,Notes\r\n"
        let rows = shifts.filter { !$0.isDeleted }.map { shift in
            let job = jobs.first { $0.id == shift.jobID }?.displayName ?? ""
            let breakMinutes = breaks.filter { $0.shiftID == shift.id && !$0.isActual }.reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
            return [shift.scheduledStart.formatted(.iso8601.year().month().day()), job, shift.scheduledStart.ISO8601Format(), shift.scheduledEnd.ISO8601Format(), shift.actualStart?.ISO8601Format() ?? "", shift.actualEnd?.ISO8601Format() ?? "", "\(breakMinutes)", shift.notes].map(csvEscape).joined(separator: ",")
        }.joined(separator: "\r\n")
        return Data([0xEF, 0xBB, 0xBF]) + Data((header + rows).utf8)
    }

    private static func csvEscape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
}
