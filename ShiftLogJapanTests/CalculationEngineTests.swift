import XCTest
@testable import ShiftLogJapan

final class CalculationEngineTests: XCTestCase {
    private var calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return value
    }()

    private func date(_ year: Int = 2026, _ month: Int = 7, _ day: Int = 14, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        date(2026, 7, 14, hour, minute)
    }

    func testSpecificationDeepNightExampleIs5325Yen() throws {
        let start = date(21), end = date(2026, 7, 15, 1)
        let breakItem = BreakInterval(start: date(23, 30), end: date(23, 45))
        let deepNight = PremiumSpec(name: "Deep Night", startMinutesFromMidnight: 22 * 60, endMinutesFromMidnight: 5 * 60, percentage: Decimal(string: "0.25")!)
        let result = try CalculationEngine.calculate(start: start, end: end, breaks: [breakItem], hourlyRate: 1_200, premiums: [deepNight], calendar: calendar)
        XCTAssertEqual(result.effectiveMinutes, 225)
        XCTAssertEqual(result.premiumMinutes["Deep Night"], 165)
        XCTAssertEqual(result.baseWage, 4_500)
        XCTAssertEqual(result.premiumWage, 825)
        XCTAssertEqual(result.total, 5_325)
    }

    func testMultipleBreaksAndOvernightMinutes() throws {
        let result = try CalculationEngine.effectiveMinutes(
            start: date(21), end: date(2026, 7, 15, 3),
            breaks: [BreakInterval(start: date(22), end: date(22, 15)), BreakInterval(start: date(2026, 7, 15, 1), end: date(2026, 7, 15, 1, 30))]
        )
        XCTAssertEqual(result, 315)
    }

    func testOverlappingBreaksAreRejected() {
        XCTAssertThrowsError(try CalculationEngine.validate(start: date(9), end: date(17), breaks: [
            BreakInterval(start: date(12), end: date(13)), BreakInterval(start: date(12, 30), end: date(13, 30))
        ])) { XCTAssertEqual($0 as? CalculationError, .overlappingBreaks) }
    }

    func testStackableAndExclusivePremiums() throws {
        let stack = PremiumSpec(name: "Stack", percentage: Decimal(string: "0.10")!)
        let low = PremiumSpec(name: "Low", percentage: Decimal(string: "0.20")!, stackable: false, priority: 1)
        let high = PremiumSpec(name: "High", percentage: Decimal(string: "0.30")!, stackable: false, priority: 10)
        let result = try CalculationEngine.calculate(start: date(9), end: date(10), breaks: [], hourlyRate: 1_000, premiums: [stack, low, high], calendar: calendar)
        XCTAssertEqual(result.baseWage, 1_000)
        XCTAssertEqual(result.premiumWage, 400)
        XCTAssertEqual(Set(result.appliedRuleNames), Set(["Stack", "High"]))
    }

    func testTimeRounding() {
        XCTAssertEqual(CalculationEngine.round(minutes: 67, interval: 15, direction: .down), 60)
        XCTAssertEqual(CalculationEngine.round(minutes: 67, interval: 15, direction: .nearest), 60)
        XCTAssertEqual(CalculationEngine.round(minutes: 68, interval: 15, direction: .nearest), 75)
        XCTAssertEqual(CalculationEngine.round(minutes: 61, interval: 15, direction: .up), 75)
    }

    func testConflictAllowsTouchingEdgesButRejectsOverlapAcrossJobs() {
        let a = ShiftInterval(id: UUID(), jobID: UUID(), start: date(9), end: date(12), breakMinutes: 0, isCancelled: false)
        let touching = ShiftInterval(id: UUID(), jobID: UUID(), start: date(12), end: date(14), breakMinutes: 0, isCancelled: false)
        let overlap = ShiftInterval(id: UUID(), jobID: UUID(), start: date(11), end: date(13), breakMinutes: 0, isCancelled: false)
        XCTAssertNil(ConflictDetector.firstConflict(for: touching, among: [a]))
        XCTAssertNotNil(ConflictDetector.firstConflict(for: overlap, among: [a]))
    }

    func testWeeklyRiskCombinesJobs() {
        let shifts = (0..<6).map { index in ShiftInterval(id: UUID(), jobID: UUID(), start: calendar.date(byAdding: .day, value: index, to: date(9))!, end: calendar.date(byAdding: .day, value: index, to: date(14))!, breakMinutes: 0, isCancelled: false) }
        let risk = WorkLimitEngine.weeklyRisk(containing: date(12), shifts: shifts, limitMinutes: 1_680, cautionMinutes: 1_440, warningMinutes: 1_560, weekStartDay: 2, calendar: calendar)
        XCTAssertEqual(risk.minutes, 1_800)
        XCTAssertEqual(risk.level, .exceeded)
    }

    func testOvernightShiftIsClippedAtWeekBoundary() {
        let start = date(2026, 7, 12, 23)
        let end = date(2026, 7, 13, 2)
        let breakItem = BreakInterval(start: date(2026, 7, 13, 0), end: date(2026, 7, 13, 1))
        let shift = ShiftInterval(id: UUID(), jobID: UUID(), start: start, end: end, breakMinutes: 60, breaks: [breakItem], isCancelled: false)
        let sunday = WorkLimitEngine.weeklyRisk(containing: start, shifts: [shift], limitMinutes: 1_680, cautionMinutes: 1_440, warningMinutes: 1_560, weekStartDay: 2, calendar: calendar)
        let monday = WorkLimitEngine.weeklyRisk(containing: end, shifts: [shift], limitMinutes: 1_680, cautionMinutes: 1_440, warningMinutes: 1_560, weekStartDay: 2, calendar: calendar)
        XCTAssertEqual(sunday.minutes, 60)
        XCTAssertEqual(monday.minutes, 60)
    }

    func testPayPeriodCrossesYearAndHandlesMonthEnd() {
        let period = PayPeriodEngine.monthly(containing: date(2026, 1, 10, 12), closingDay: 15, payDay: 31, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: period.start), 2025)
        XCTAssertEqual(calendar.component(.month, from: period.start), 12)
        XCTAssertEqual(calendar.component(.day, from: period.start), 16)
        XCTAssertEqual(calendar.component(.day, from: period.payDate), 31)
    }

    func testNullAdProviderNeverReturnsContent() {
        XCTAssertNil(NullAdProvider().contentIdentifier(for: .calendarSummary))
        XCTAssertFalse(AppConfiguration.advertisingEnabled)
    }

    func testStartDateChangeKeepsEndTimeAndSynchronizesDay() {
        let start = date(2026, 7, 20, 9)
        let oldEnd = date(2026, 7, 14, 17, 30)
        let result = ShiftDateLinker.afterStartChange(start: start, end: oldEnd, crossDayEnabled: false, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: result.end), 20)
        XCTAssertEqual(calendar.component(.hour, from: result.end), 17)
        XCTAssertEqual(calendar.component(.minute, from: result.end), 30)
    }

    func testEndDateChangeKeepsStartTimeAndSynchronizesDay() {
        let oldStart = date(2026, 7, 14, 9, 15)
        let end = date(2026, 7, 22, 18)
        let result = ShiftDateLinker.afterEndChange(start: oldStart, end: end, crossDayEnabled: false, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: result.start), 22)
        XCTAssertEqual(calendar.component(.hour, from: result.start), 9)
        XCTAssertEqual(calendar.component(.minute, from: result.start), 15)
    }

    func testCrossDayToggleAndSelectedDateDefault() {
        let selectedDate = date(2026, 7, 20, 12)
        let defaults = ShiftDateLinker.defaultRange(for: selectedDate, calendar: calendar)
        XCTAssertTrue(calendar.isDate(defaults.start, inSameDayAs: selectedDate))
        XCTAssertTrue(calendar.isDate(defaults.end, inSameDayAs: selectedDate))

        let overnightEnd = ShiftDateLinker.promoteEndToNextDay(start: date(21), end: date(2), calendar: calendar)
        XCTAssertEqual(overnightEnd, date(2026, 7, 15, 2))
        let singleDay = ShiftDateLinker.disablingCrossDay(start: date(21), end: overnightEnd, calendar: calendar)
        XCTAssertTrue(calendar.isDate(singleDay.start, inSameDayAs: singleDay.end))
    }

    func testJPYInputAcceptsGroupingAndFullWidthDigits() throws {
        XCTAssertEqual(try WageInputParser.parseJPY("1,350"), 1_350)
        XCTAssertEqual(try WageInputParser.parseJPY("１２００"), 1_200)
        XCTAssertEqual(WageInputParser.formatJPY(1_200, locale: Locale(identifier: "en_US")), "1,200")
    }

    func testJPYInputRejectsEmptyZeroNegativeAndText() {
        XCTAssertThrowsError(try WageInputParser.parseJPY("")) { XCTAssertEqual($0 as? WageInputError, .empty) }
        XCTAssertThrowsError(try WageInputParser.parseJPY("0")) { XCTAssertEqual($0 as? WageInputError, .nonPositive) }
        XCTAssertThrowsError(try WageInputParser.parseJPY("-1200")) { XCTAssertEqual($0 as? WageInputError, .invalid) }
        XCTAssertThrowsError(try WageInputParser.parseJPY("abc")) { XCTAssertEqual($0 as? WageInputError, .invalid) }
    }

    func testWageHistorySelectsRateEffectiveOnShiftDate() {
        let jobID = UUID()
        let old = WageRate(jobID: jobID, hourlyAmount: 1_200, effectiveFrom: date(2026, 1, 1, 0))
        old.effectiveTo = date(2026, 7, 1, 0)
        let current = WageRate(jobID: jobID, hourlyAmount: 1_350, effectiveFrom: date(2026, 7, 1, 0))
        XCTAssertEqual(ModelAdapters.wageRate(for: jobID, on: date(2026, 6, 1, 9), rates: [old, current]), 1_200)
        XCTAssertEqual(ModelAdapters.wageRate(for: jobID, on: date(2026, 7, 20, 9), rates: [old, current]), 1_350)
    }

    func testEarningsRangeTitlesNeverExposeLocalizationKeys() {
        XCTAssertEqual(Set(EarningsRange.allCases.map(\.rawValue)), Set(["day", "week", "month", "year", "custom"]))
        XCTAssertTrue(EarningsRange.allCases.allSatisfy { !$0.localizedTitle.hasPrefix("range.") && !$0.localizedTitle.isEmpty })
    }
}
