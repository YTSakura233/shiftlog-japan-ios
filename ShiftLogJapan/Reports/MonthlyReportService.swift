import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MonthlyReportJobSummary: Equatable, Sendable {
    let jobName: String
    let colorHex: String
    let shiftCount: Int
    let minutes: Int
    let baseWage: Decimal
    let premiumWage: Decimal
    let transport: Decimal
    let total: Decimal
}

struct MonthlyReportShiftRow: Equatable, Sendable {
    let jobName: String
    let colorHex: String
    let start: Date
    let end: Date
    let minutes: Int
    let total: Decimal
}

struct MonthlyReportPaymentRow: Equatable, Sendable {
    let jobName: String
    let periodStart: Date
    let periodEnd: Date
    let gross: Decimal?
    let deductions: Decimal
    let received: Decimal?
}

struct MonthlyReport: Equatable, Sendable {
    let month: Date
    let generatedAt: Date
    let localeIdentifier: String
    let sourceTitle: String
    let jobSummaries: [MonthlyReportJobSummary]
    let shifts: [MonthlyReportShiftRow]
    let payments: [MonthlyReportPaymentRow]

    var totalMinutes: Int { jobSummaries.reduce(0) { $0 + $1.minutes } }
    var totalAmount: Decimal { jobSummaries.reduce(0) { $0 + $1.total } }
}

struct MonthlyReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum MonthlyReportService {
    private static let pageSize = CGSize(width: 595.28, height: 841.89)
    private static let pageMargin: CGFloat = 42
    private static let accent = UIColor(red: 49 / 255, green: 92 / 255, blue: 140 / 255, alpha: 1)
    private static let ink = UIColor(red: 28 / 255, green: 39 / 255, blue: 56 / 255, alpha: 1)
    private static let secondaryInk = UIColor(red: 92 / 255, green: 104 / 255, blue: 120 / 255, alpha: 1)
    private static let paleFill = UIColor(red: 244 / 255, green: 247 / 255, blue: 250 / 255, alpha: 1)

    static func makeReport(
        month: Date,
        source: TimeSource,
        locale: Locale,
        jobs: [Job],
        shifts: [Shift],
        breaks: [ShiftBreak],
        rates: [WageRate],
        premiumRules: [PremiumRule],
        payments: [Payment],
        calendar: Calendar = .current,
        generatedAt: Date = Date()
    ) -> MonthlyReport {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month.startOfMonth
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? month.endOfMonth
        let jobsByID = Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0) })
        let useActual = source == .actual

        let rows: [(UUID, MonthlyReportShiftRow, WageCalculation)] = shifts
            .filter {
                !$0.isDeleted && $0.status != .cancelled
            }
            .compactMap { shift in
                guard shift.status != .absent || source == .scheduled,
                      let job = jobsByID[shift.jobID],
                      !useActual || shift.actualConfirmed,
                      let calculationStart = useActual ? shift.actualStart : shift.scheduledStart,
                      let calculationEnd = useActual ? shift.actualEnd : shift.scheduledEnd,
                      calculationStart < end,
                      calculationEnd > start,
                      let calculation = try? CalculationEngine.calculate(
                        start: calculationStart,
                        end: calculationEnd,
                        breaks: ModelAdapters.breaks(for: shift.id, actual: useActual, all: breaks),
                        hourlyRate: ModelAdapters.wageRate(for: shift.jobID, on: calculationStart, rates: rates),
                        premiums: ModelAdapters.premiumSpecs(for: shift.jobID, on: calculationStart, rules: premiumRules),
                        transport: shift.transportAmount,
                        bonus: shift.bonusAmount,
                        deduction: shift.deductionAmount,
                        roundingInterval: job.roundingIntervalMinutes,
                        roundingDirection: job.roundingDirection,
                        wageRoundingUnit: job.wageRoundingUnit,
                        calendar: calendar
                      ) else { return nil }
                return (
                    shift.jobID,
                    MonthlyReportShiftRow(
                        jobName: job.displayName,
                        colorHex: job.colorHex,
                        start: calculationStart,
                        end: calculationEnd,
                        minutes: calculation.effectiveMinutes,
                        total: calculation.total
                    ),
                    calculation
                )
            }
            .sorted { $0.1.start < $1.1.start }

        let jobSummaries = jobs.compactMap { job -> MonthlyReportJobSummary? in
            let jobRows = rows.filter { $0.0 == job.id }
            guard !jobRows.isEmpty else { return nil }
            return MonthlyReportJobSummary(
                jobName: job.displayName,
                colorHex: job.colorHex,
                shiftCount: jobRows.count,
                minutes: jobRows.reduce(0) { $0 + $1.2.effectiveMinutes },
                baseWage: jobRows.reduce(0) { $0 + $1.2.baseWage },
                premiumWage: jobRows.reduce(0) { $0 + $1.2.premiumWage },
                transport: jobRows.reduce(0) { $0 + $1.2.transport },
                total: jobRows.reduce(0) { $0 + $1.2.total }
            )
        }
        .sorted { $0.jobName.localizedStandardCompare($1.jobName) == .orderedAscending }

        let paymentRows = payments
            .filter { $0.periodStart < end && $0.periodEnd >= start }
            .compactMap { payment -> MonthlyReportPaymentRow? in
                guard let job = jobsByID[payment.jobID] else { return nil }
                return MonthlyReportPaymentRow(
                    jobName: job.displayName,
                    periodStart: payment.periodStart,
                    periodEnd: payment.periodEnd,
                    gross: payment.grossAmount,
                    deductions: payment.deductions,
                    received: payment.receivedAmount
                )
            }
            .sorted { $0.periodStart < $1.periodStart }

        return MonthlyReport(
            month: start,
            generatedAt: generatedAt,
            localeIdentifier: locale.identifier,
            sourceTitle: source.localizedTitle(locale: locale),
            jobSummaries: jobSummaries,
            shifts: rows.map(\.1),
            payments: paymentRows
        )
    }

    static func render(_ report: MonthlyReport) -> Data {
        let bounds = CGRect(origin: .zero, size: pageSize)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: localized("report.monthly", defaultValue: "Monthly work report", report: report),
            kCGPDFContextAuthor as String: "勤记"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        return renderer.pdfData { context in
            let contentWidth = pageSize.width - pageMargin * 2
            let bottomLimit = pageSize.height - 52
            var pageNumber = 0
            var y: CGFloat = 0

            func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
                let rect = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font],
                    context: nil
                )
                return ceil(rect.height)
            }

            func drawText(
                _ text: String,
                x: CGFloat,
                y: CGFloat,
                width: CGFloat,
                font: UIFont,
                color: UIColor = ink,
                alignment: NSTextAlignment = .left,
                maxHeight: CGFloat? = nil
            ) -> CGFloat {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = alignment
                paragraph.lineBreakMode = .byTruncatingTail
                let height = maxHeight ?? textHeight(text, font: font, width: width)
                (text as NSString).draw(
                    in: CGRect(x: x, y: y, width: width, height: height),
                    withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
                )
                return height
            }

            func beginPage() {
                context.beginPage()
                pageNumber += 1
                accent.setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageSize.width, height: 9)).fill()
                _ = drawText(
                    localized("report.monthly", defaultValue: "Monthly work report", report: report),
                    x: pageMargin,
                    y: 24,
                    width: contentWidth - 80,
                    font: .systemFont(ofSize: 12, weight: .semibold),
                    color: accent
                )
                _ = drawText(
                    "\(pageNumber)",
                    x: pageSize.width - pageMargin - 50,
                    y: 24,
                    width: 50,
                    font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                    color: secondaryInk,
                    alignment: .right
                )
                y = 52
            }

            func ensureSpace(_ height: CGFloat) {
                if y + height > bottomLimit { beginPage() }
            }

            func drawSectionTitle(_ title: String) {
                ensureSpace(38)
                y += 10
                accent.setFill()
                UIBezierPath(roundedRect: CGRect(x: pageMargin, y: y + 1, width: 4, height: 18), cornerRadius: 2).fill()
                _ = drawText(title, x: pageMargin + 12, y: y, width: contentWidth - 12, font: .systemFont(ofSize: 16, weight: .bold))
                y += 30
            }

            func drawTableHeader(_ columns: [(String, CGFloat, NSTextAlignment)]) {
                ensureSpace(28)
                paleFill.setFill()
                UIBezierPath(roundedRect: CGRect(x: pageMargin, y: y, width: contentWidth, height: 25), cornerRadius: 6).fill()
                var x = pageMargin + 8
                for (title, width, alignment) in columns {
                    _ = drawText(title, x: x, y: y + 6, width: width - 8, font: .systemFont(ofSize: 9, weight: .semibold), color: secondaryInk, alignment: alignment, maxHeight: 14)
                    x += width
                }
                y += 29
            }

            func drawRule() {
                UIColor.separator.withAlphaComponent(0.35).setStroke()
                let path = UIBezierPath()
                path.move(to: CGPoint(x: pageMargin, y: y))
                path.addLine(to: CGPoint(x: pageSize.width - pageMargin, y: y))
                path.lineWidth = 0.5
                path.stroke()
            }

            beginPage()

            let locale = Locale(identifier: report.localeIdentifier)
            let monthTitle = report.month.formatted(.dateTime.year().month(.wide).locale(locale))
            _ = drawText(monthTitle, x: pageMargin, y: y, width: contentWidth, font: .systemFont(ofSize: 30, weight: .bold))
            y += 40
            let metadata = "\(localized("report.source", defaultValue: "Source", report: report)): \(report.sourceTitle)    \(localized("report.generated", defaultValue: "Generated", report: report)): \(dateString(report.generatedAt, locale: locale))"
            _ = drawText(metadata, x: pageMargin, y: y, width: contentWidth, font: .systemFont(ofSize: 10), color: secondaryInk)
            y += 28

            let cardGap: CGFloat = 10
            let cardWidth = (contentWidth - cardGap * 2) / 3
            let cards = [
                (localized("report.total", defaultValue: "Estimated total", report: report), currency(report.totalAmount, locale: locale)),
                (localized("earnings.hours", defaultValue: "Hours", report: report), duration(report.totalMinutes)),
                (localized("report.shifts", defaultValue: "Shifts", report: report), "\(report.shifts.count)")
            ]
            for (index, card) in cards.enumerated() {
                let x = pageMargin + CGFloat(index) * (cardWidth + cardGap)
                paleFill.setFill()
                UIBezierPath(roundedRect: CGRect(x: x, y: y, width: cardWidth, height: 72), cornerRadius: 12).fill()
                _ = drawText(card.0, x: x + 12, y: y + 12, width: cardWidth - 24, font: .systemFont(ofSize: 9, weight: .medium), color: secondaryInk)
                _ = drawText(card.1, x: x + 12, y: y + 34, width: cardWidth - 24, font: .monospacedDigitSystemFont(ofSize: 17, weight: .bold))
            }
            y += 82

            drawSectionTitle(localized("report.jobBreakdown", defaultValue: "By job", report: report))
            let jobColumns: [(String, CGFloat, NSTextAlignment)] = [
                (localized("tab.jobs", defaultValue: "Job", report: report), 128, .left),
                (localized("report.shifts", defaultValue: "Shifts", report: report), 47, .right),
                (localized("earnings.hours", defaultValue: "Hours", report: report), 60, .right),
                (localized("report.base", defaultValue: "Base", report: report), 78, .right),
                (localized("report.premium", defaultValue: "Premium", report: report), 78, .right),
                (localized("report.total", defaultValue: "Total", report: report), contentWidth - 391, .right)
            ]
            drawTableHeader(jobColumns)
            if report.jobSummaries.isEmpty {
                _ = drawText(localized("report.noData", defaultValue: "No data for this month", report: report), x: pageMargin + 8, y: y + 6, width: contentWidth - 16, font: .systemFont(ofSize: 10), color: secondaryInk)
                y += 28
            } else {
                for job in report.jobSummaries {
                    ensureSpace(31)
                    var x = pageMargin + 8
                    let values: [(String, CGFloat, NSTextAlignment)] = [
                        (job.jobName, 128, .left),
                        ("\(job.shiftCount)", 47, .right),
                        (duration(job.minutes), 60, .right),
                        (currency(job.baseWage, locale: locale), 78, .right),
                        (currency(job.premiumWage, locale: locale), 78, .right),
                        (currency(job.total, locale: locale), contentWidth - 391, .right)
                    ]
                    for (value, width, alignment) in values {
                        _ = drawText(value, x: x, y: y + 6, width: width - 8, font: .systemFont(ofSize: 9.5, weight: alignment == .left ? .medium : .regular), alignment: alignment, maxHeight: 16)
                        x += width
                    }
                    y += 27
                    drawRule()
                }
            }

            drawSectionTitle(localized("report.shiftDetails", defaultValue: "Shift details", report: report))
            let shiftColumns: [(String, CGFloat, NSTextAlignment)] = [
                (localized("range.day", defaultValue: "Date", report: report), 82, .left),
                (localized("tab.jobs", defaultValue: "Job", report: report), 132, .left),
                (localized("shift.start", defaultValue: "Time", report: report), 116, .left),
                (localized("earnings.hours", defaultValue: "Hours", report: report), 62, .right),
                (localized("report.total", defaultValue: "Total", report: report), contentWidth - 392, .right)
            ]
            drawTableHeader(shiftColumns)
            if report.shifts.isEmpty {
                _ = drawText(localized("report.noData", defaultValue: "No data for this month", report: report), x: pageMargin + 8, y: y + 6, width: contentWidth - 16, font: .systemFont(ofSize: 10), color: secondaryInk)
                y += 28
            } else {
                for shift in report.shifts {
                    if y + 28 > bottomLimit {
                        beginPage()
                        drawSectionTitle(localized("report.shiftDetails", defaultValue: "Shift details", report: report))
                        drawTableHeader(shiftColumns)
                    }
                    var x = pageMargin + 8
                    let values: [(String, CGFloat, NSTextAlignment)] = [
                        (shift.start.formatted(.dateTime.month().day().weekday(.abbreviated).locale(locale)), 82, .left),
                        (shift.jobName, 132, .left),
                        (timeRange(shift.start, shift.end, locale: locale), 116, .left),
                        (duration(shift.minutes), 62, .right),
                        (currency(shift.total, locale: locale), contentWidth - 392, .right)
                    ]
                    for (value, width, alignment) in values {
                        _ = drawText(value, x: x, y: y + 6, width: width - 8, font: .systemFont(ofSize: 9), alignment: alignment, maxHeight: 15)
                        x += width
                    }
                    y += 26
                    drawRule()
                }
            }

            if !report.payments.isEmpty {
                drawSectionTitle(localized("report.payments", defaultValue: "Payments", report: report))
                let paymentColumns: [(String, CGFloat, NSTextAlignment)] = [
                    (localized("tab.jobs", defaultValue: "Job", report: report), 125, .left),
                    (localized("earnings.range", defaultValue: "Period", report: report), 130, .left),
                    (localized("payment.gross", defaultValue: "Gross", report: report), 85, .right),
                    (localized("payment.deductions", defaultValue: "Deductions", report: report), 80, .right),
                    (localized("payment.received", defaultValue: "Received", report: report), contentWidth - 420, .right)
                ]
                drawTableHeader(paymentColumns)
                for payment in report.payments {
                    ensureSpace(29)
                    var x = pageMargin + 8
                    let period = paymentPeriod(payment.periodStart, payment.periodEnd, locale: locale)
                    let values: [(String, CGFloat, NSTextAlignment)] = [
                        (payment.jobName, 125, .left),
                        (period, 130, .left),
                        (payment.gross.map { currency($0, locale: locale) } ?? "-", 85, .right),
                        (currency(payment.deductions, locale: locale), 80, .right),
                        (payment.received.map { currency($0, locale: locale) } ?? "-", contentWidth - 420, .right)
                    ]
                    for (value, width, alignment) in values {
                        _ = drawText(value, x: x, y: y + 6, width: width - 8, font: .systemFont(ofSize: 9), alignment: alignment, maxHeight: 15)
                        x += width
                    }
                    y += 26
                    drawRule()
                }
            }

            let disclaimer = localized("report.disclaimer", defaultValue: "This report is an estimate for personal record keeping and is not a payslip, tax document, or legal advice.", report: report)
            let disclaimerHeight = textHeight(disclaimer, font: .systemFont(ofSize: 9), width: contentWidth - 24) + 24
            ensureSpace(disclaimerHeight + 12)
            y += 14
            paleFill.setFill()
            UIBezierPath(roundedRect: CGRect(x: pageMargin, y: y, width: contentWidth, height: disclaimerHeight), cornerRadius: 9).fill()
            _ = drawText(disclaimer, x: pageMargin + 12, y: y + 12, width: contentWidth - 24, font: .systemFont(ofSize: 9), color: secondaryInk)
        }
    }

    static func filename(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM"
        return "ShiftLog-Monthly-\(formatter.string(from: month)).pdf"
    }

    private static func localized(_ key: String, defaultValue: String, report: MonthlyReport) -> String {
        AppLocalization.string(key, defaultValue: defaultValue, locale: Locale(identifier: report.localeIdentifier))
    }

    private static func currency(_ amount: Decimal, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = AppConfiguration.currencyCode
        formatter.maximumFractionDigits = 0
        formatter.locale = locale
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }

    private static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    private static func dateString(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute().locale(locale))
    }

    private static func paymentPeriod(_ start: Date, _ end: Date, locale: Locale) -> String {
        let startFormatter = DateFormatter()
        startFormatter.locale = locale
        startFormatter.dateFormat = "yyyy/MM/dd"
        let endFormatter = DateFormatter()
        endFormatter.locale = locale
        endFormatter.dateFormat = "MM/dd"
        return "\(startFormatter.string(from: start))-\(endFormatter.string(from: end))"
    }

    private static func timeRange(_ start: Date, _ end: Date, locale: Locale) -> String {
        let startText = start.formatted(.dateTime.hour().minute().locale(locale))
        let endText = end.formatted(.dateTime.hour().minute().locale(locale))
        return "\(startText) - \(endText)"
    }
}
