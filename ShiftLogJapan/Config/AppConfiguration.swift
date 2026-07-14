import Foundation

enum AppConfiguration {
    static let displayNameKey = "app.name"
    static let currencyCode = "JPY"
    static let calendarTitle = "ShiftLog"
    static let advertisingEnabled = false
    static let cloudKitContainerIdentifier = "iCloud.com.example.shiftlog"
    static let subscriptionProductIDs = [
        "com.example.shiftlog.removeads.monthly",
        "com.example.shiftlog.removeads.quarterly",
        "com.example.shiftlog.removeads.yearly"
    ]
}
