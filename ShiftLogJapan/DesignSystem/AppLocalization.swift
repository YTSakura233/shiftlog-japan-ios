import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case english = "en"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .english: "English"
        }
    }

    static func preferred(for locale: Locale = .current) -> AppLanguage {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if identifier.hasPrefix("zh-hant") || identifier.hasPrefix("zh-tw") || identifier.hasPrefix("zh-hk") || identifier.hasPrefix("zh-mo") {
            return .traditionalChinese
        }
        if identifier.hasPrefix("zh") { return .simplifiedChinese }
        if identifier.hasPrefix("ja") { return .japanese }
        return .english
    }
}

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

    static func supportedResource(for locale: Locale) -> String {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if identifier.hasPrefix("zh-hant") || identifier.hasPrefix("zh-tw") || identifier.hasPrefix("zh-hk") || identifier.hasPrefix("zh-mo") {
            return "zh-Hant"
        }
        if identifier.hasPrefix("zh") { return "zh-Hans" }
        if identifier.hasPrefix("ja") { return "ja" }
        return "en"
    }
}
