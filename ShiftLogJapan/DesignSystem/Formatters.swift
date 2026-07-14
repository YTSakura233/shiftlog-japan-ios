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

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }

    var endOfMonth: Date { Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)! }
}
