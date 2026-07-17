import Foundation

enum AppConfiguration {
    static let currencyCode = "JPY"
    static let calendarTitle = "勤记"
    static let legacyCalendarTitles: Set<String> = ["ShiftLog"]
    static let appGroupIdentifier = "group.com.example.shiftlogjapan"
    static let githubURL = URL(string: "https://github.com/YTSakura233/shiftlog-japan-ios")!
    static let websiteURL = URL(string: "https://ytsakura233.github.io/shiftlog-japan-ios/")!

    static func recognizesCalendarTitle(_ title: String) -> Bool {
        title == calendarTitle || legacyCalendarTitles.contains(title)
    }
}
