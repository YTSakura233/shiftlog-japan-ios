import Foundation

enum AppLocalization {
    static func string(_ key: String, defaultValue: String, locale: Locale) -> String {
        let resource = supportedResource(for: locale)
        guard
            let path = Bundle.main.path(forResource: resource, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return defaultValue
        }
        return bundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    private static func supportedResource(for locale: Locale) -> String {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if identifier.hasPrefix("zh") { return "zh-Hans" }
        if identifier.hasPrefix("ja") { return "ja" }
        return "en"
    }
}
