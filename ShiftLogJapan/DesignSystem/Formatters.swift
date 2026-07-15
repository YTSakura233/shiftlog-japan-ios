import Foundation

enum CurrencyFormatter {
    static func string(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: AppConfiguration.currencyCode).precision(.fractionLength(0)))
    }
}

enum DurationFormatter {
    static func string(minutes: Int) -> String {
        let hours = minutes / 60, remaining = minutes % 60
        return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
    }
}

struct PeriodHeading: Equatable {
    let title: String
    let subtitle: String?
}

enum PeriodHeadingFormatter {
    static func day(_ date: Date, locale: Locale) -> PeriodHeading {
        PeriodHeading(title: date.formatted(.dateTime.year().month().day().locale(locale)), subtitle: nil)
    }

    static func month(_ date: Date, locale: Locale) -> PeriodHeading {
        PeriodHeading(title: date.formatted(.dateTime.year().month(.wide).locale(locale)), subtitle: nil)
    }

    static func year(_ date: Date, locale: Locale) -> PeriodHeading {
        PeriodHeading(title: date.formatted(.dateTime.year().locale(locale)), subtitle: nil)
    }

    static func week(containing date: Date, interval: DateInterval, locale: Locale, calendar: Calendar = .current) -> PeriodHeading {
        let monthTitle = month(date, locale: locale).title
        let weekNumber = max(1, calendar.component(.weekOfMonth, from: date))
        let weekNumberText = localizedWeekNumber(weekNumber, locale: locale)
        let titleFormat = AppLocalization.string("period.week.title", defaultValue: "Week %2$@ of %1$@", locale: locale)
        let title = String(format: titleFormat, locale: locale, arguments: [monthTitle, weekNumberText])
        let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end.addingTimeInterval(-1)
        let startText = interval.start.formatted(.dateTime.year().month().day().locale(locale))
        let endText = endDate.formatted(.dateTime.year().month().day().locale(locale))
        let rangeFormat = AppLocalization.string("period.range", defaultValue: "%1$@ – %2$@", locale: locale)
        let subtitle = String(format: rangeFormat, locale: locale, arguments: [startText, endText])
        return PeriodHeading(title: title, subtitle: subtitle)
    }

    private static func localizedWeekNumber(_ number: Int, locale: Locale) -> String {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        guard identifier.hasPrefix("zh") else { return String(number) }
        let chineseNumerals = ["一", "二", "三", "四", "五", "六"]
        guard chineseNumerals.indices.contains(number - 1) else { return String(number) }
        return chineseNumerals[number - 1]
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }

    var endOfMonth: Date { Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)! }
}
