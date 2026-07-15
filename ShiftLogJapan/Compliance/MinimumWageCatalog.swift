import Foundation

struct PrefectureInfo: Identifiable, Hashable {
    let code: String
    let japaneseName: String
    let englishName: String
    var id: String { code }

    func localizedName(locale: Locale) -> String {
        locale.language.languageCode?.identifier == "en" ? englishName : japaneseName
    }
}

struct MinimumWageRecordValue: Equatable {
    let prefectureCode: String
    let hourlyAmount: Decimal
    let effectiveFrom: Date
    let effectiveTo: Date?
    let sourceURL: URL
    let sourceCheckedAt: Date
}

enum MinimumWageAssessment: Equatable {
    case missingPrefecture
    case unavailable
    case stale(MinimumWageRecordValue)
    case below(MinimumWageRecordValue)
    case compliant(MinimumWageRecordValue)
}

struct MinimumWageCatalog {
    static let officialSourceURL = URL(string: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/minimumichiran/")!
    static let prefectures: [PrefectureInfo] = [
        .init(code: "JP-01", japaneseName: "北海道", englishName: "Hokkaido"),
        .init(code: "JP-02", japaneseName: "青森県", englishName: "Aomori"),
        .init(code: "JP-03", japaneseName: "岩手県", englishName: "Iwate"),
        .init(code: "JP-04", japaneseName: "宮城県", englishName: "Miyagi"),
        .init(code: "JP-05", japaneseName: "秋田県", englishName: "Akita"),
        .init(code: "JP-06", japaneseName: "山形県", englishName: "Yamagata"),
        .init(code: "JP-07", japaneseName: "福島県", englishName: "Fukushima"),
        .init(code: "JP-08", japaneseName: "茨城県", englishName: "Ibaraki"),
        .init(code: "JP-09", japaneseName: "栃木県", englishName: "Tochigi"),
        .init(code: "JP-10", japaneseName: "群馬県", englishName: "Gunma"),
        .init(code: "JP-11", japaneseName: "埼玉県", englishName: "Saitama"),
        .init(code: "JP-12", japaneseName: "千葉県", englishName: "Chiba"),
        .init(code: "JP-13", japaneseName: "東京都", englishName: "Tokyo"),
        .init(code: "JP-14", japaneseName: "神奈川県", englishName: "Kanagawa"),
        .init(code: "JP-15", japaneseName: "新潟県", englishName: "Niigata"),
        .init(code: "JP-16", japaneseName: "富山県", englishName: "Toyama"),
        .init(code: "JP-17", japaneseName: "石川県", englishName: "Ishikawa"),
        .init(code: "JP-18", japaneseName: "福井県", englishName: "Fukui"),
        .init(code: "JP-19", japaneseName: "山梨県", englishName: "Yamanashi"),
        .init(code: "JP-20", japaneseName: "長野県", englishName: "Nagano"),
        .init(code: "JP-21", japaneseName: "岐阜県", englishName: "Gifu"),
        .init(code: "JP-22", japaneseName: "静岡県", englishName: "Shizuoka"),
        .init(code: "JP-23", japaneseName: "愛知県", englishName: "Aichi"),
        .init(code: "JP-24", japaneseName: "三重県", englishName: "Mie"),
        .init(code: "JP-25", japaneseName: "滋賀県", englishName: "Shiga"),
        .init(code: "JP-26", japaneseName: "京都府", englishName: "Kyoto"),
        .init(code: "JP-27", japaneseName: "大阪府", englishName: "Osaka"),
        .init(code: "JP-28", japaneseName: "兵庫県", englishName: "Hyogo"),
        .init(code: "JP-29", japaneseName: "奈良県", englishName: "Nara"),
        .init(code: "JP-30", japaneseName: "和歌山県", englishName: "Wakayama"),
        .init(code: "JP-31", japaneseName: "鳥取県", englishName: "Tottori"),
        .init(code: "JP-32", japaneseName: "島根県", englishName: "Shimane"),
        .init(code: "JP-33", japaneseName: "岡山県", englishName: "Okayama"),
        .init(code: "JP-34", japaneseName: "広島県", englishName: "Hiroshima"),
        .init(code: "JP-35", japaneseName: "山口県", englishName: "Yamaguchi"),
        .init(code: "JP-36", japaneseName: "徳島県", englishName: "Tokushima"),
        .init(code: "JP-37", japaneseName: "香川県", englishName: "Kagawa"),
        .init(code: "JP-38", japaneseName: "愛媛県", englishName: "Ehime"),
        .init(code: "JP-39", japaneseName: "高知県", englishName: "Kochi"),
        .init(code: "JP-40", japaneseName: "福岡県", englishName: "Fukuoka"),
        .init(code: "JP-41", japaneseName: "佐賀県", englishName: "Saga"),
        .init(code: "JP-42", japaneseName: "長崎県", englishName: "Nagasaki"),
        .init(code: "JP-43", japaneseName: "熊本県", englishName: "Kumamoto"),
        .init(code: "JP-44", japaneseName: "大分県", englishName: "Oita"),
        .init(code: "JP-45", japaneseName: "宮崎県", englishName: "Miyazaki"),
        .init(code: "JP-46", japaneseName: "鹿児島県", englishName: "Kagoshima"),
        .init(code: "JP-47", japaneseName: "沖縄県", englishName: "Okinawa")
    ]

    let records: [MinimumWageRecordValue]

    init(records: [MinimumWageRecordValue] = Self.bundledRecords) {
        self.records = records
    }

    func record(prefectureCode: String, on date: Date) -> MinimumWageRecordValue? {
        records
            .filter { $0.prefectureCode == prefectureCode && $0.effectiveFrom <= date && ($0.effectiveTo == nil || date < $0.effectiveTo!) }
            .max { $0.effectiveFrom < $1.effectiveFrom }
    }

    func assess(prefectureCode: String, hourlyAmount: Decimal, on date: Date, referenceDate: Date = Date()) -> MinimumWageAssessment {
        guard !prefectureCode.isEmpty else { return .missingPrefecture }
        guard let record = record(prefectureCode: prefectureCode, on: date) else { return .unavailable }
        if referenceDate > Calendar(identifier: .gregorian).date(byAdding: .day, value: 400, to: record.sourceCheckedAt)! {
            return .stale(record)
        }
        return hourlyAmount < record.hourlyAmount ? .below(record) : .compliant(record)
    }

    private static let bundledRecords: [MinimumWageRecordValue] = {
        let sourceCheckedAt = day("2026-07-09")
        let values: [(String, Int, String)] = [
            ("JP-01", 1075, "2025-10-04"), ("JP-02", 1029, "2025-11-21"),
            ("JP-03", 1031, "2025-12-01"), ("JP-04", 1038, "2025-10-04"),
            ("JP-05", 1031, "2026-03-31"), ("JP-06", 1032, "2025-12-23"),
            ("JP-07", 1033, "2026-01-01"), ("JP-08", 1074, "2025-10-12"),
            ("JP-09", 1068, "2025-10-01"), ("JP-10", 1063, "2026-03-01"),
            ("JP-11", 1141, "2025-11-01"), ("JP-12", 1140, "2025-10-03"),
            ("JP-13", 1226, "2025-10-03"), ("JP-14", 1225, "2025-10-04"),
            ("JP-15", 1050, "2025-10-02"), ("JP-16", 1062, "2025-10-12"),
            ("JP-17", 1054, "2025-10-08"), ("JP-18", 1053, "2025-10-08"),
            ("JP-19", 1052, "2025-12-01"), ("JP-20", 1061, "2025-10-03"),
            ("JP-21", 1065, "2025-10-18"), ("JP-22", 1097, "2025-11-01"),
            ("JP-23", 1140, "2025-10-18"), ("JP-24", 1087, "2025-11-21"),
            ("JP-25", 1080, "2025-10-05"), ("JP-26", 1122, "2025-11-21"),
            ("JP-27", 1177, "2025-10-16"), ("JP-28", 1116, "2025-10-04"),
            ("JP-29", 1051, "2025-11-16"), ("JP-30", 1045, "2025-11-01"),
            ("JP-31", 1030, "2025-10-04"), ("JP-32", 1033, "2025-11-17"),
            ("JP-33", 1047, "2025-12-01"), ("JP-34", 1085, "2025-11-01"),
            ("JP-35", 1043, "2025-10-16"), ("JP-36", 1046, "2026-01-01"),
            ("JP-37", 1036, "2025-10-18"), ("JP-38", 1033, "2025-12-01"),
            ("JP-39", 1023, "2025-12-01"), ("JP-40", 1057, "2025-11-16"),
            ("JP-41", 1030, "2025-11-21"), ("JP-42", 1031, "2025-12-01"),
            ("JP-43", 1034, "2026-01-01"), ("JP-44", 1035, "2026-01-01"),
            ("JP-45", 1023, "2025-11-16"), ("JP-46", 1026, "2025-11-01"),
            ("JP-47", 1023, "2025-12-01")
        ]
        return values.map { code, amount, effective in
            MinimumWageRecordValue(prefectureCode: code, hourlyAmount: Decimal(amount), effectiveFrom: day(effective), effectiveTo: nil, sourceURL: officialSourceURL, sourceCheckedAt: sourceCheckedAt)
        }
    }()

    private static func day(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value + "T00:00:00+09:00")!
    }
}
