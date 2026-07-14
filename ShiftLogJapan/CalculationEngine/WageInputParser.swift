import Foundation

enum WageInputError: Error, Equatable {
    case empty
    case invalid
    case nonPositive
}

enum WageInputParser {
    static func parseJPY(_ input: String) throws -> Decimal {
        let halfWidth = input.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? input
        let cleaned = halfWidth
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { throw WageInputError.empty }
        guard cleaned.allSatisfy(\.isNumber), let amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
            throw WageInputError.invalid
        }
        guard amount > 0 else { throw WageInputError.nonPositive }
        return amount
    }

    static func formatJPY(_ amount: Decimal, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? NSDecimalNumber(decimal: amount).stringValue
    }
}
