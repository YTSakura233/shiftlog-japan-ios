import SwiftUI
import WidgetKit

private enum ShiftLogWidgetConstants {
    static let appGroupIdentifier = "group.com.example.shiftlogjapan"
    static let storageKey = "shiftlog.widget.snapshot.v1"
    static let kind = "ShiftLogSummaryWidget"
}

private struct WidgetShift: Codable, Equatable {
    let jobName: String
    let start: Date
    let end: Date
    let colorHex: String
    let effectiveMinutes: Int
}

private struct WidgetSnapshot: Codable, Equatable {
    let generatedAt: Date
    let localeCode: String
    let scheduledShifts: [WidgetShift]
}

private struct ShiftLogEntry: TimelineEntry {
    let date: Date
    let localeCode: String
    let nextShift: WidgetShift?
    let weeklyMinutes: Int
    let weeklyShiftCount: Int

    static let placeholder = ShiftLogEntry(
        date: Date(),
        localeCode: "zh-Hans",
        nextShift: WidgetShift(
            jobName: "便利店",
            start: Date().addingTimeInterval(3_600),
            end: Date().addingTimeInterval(5 * 3_600),
            colorHex: "5B7DB1",
            effectiveMinutes: 240
        ),
        weeklyMinutes: 960,
        weeklyShiftCount: 4
    )
}

private struct ShiftLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShiftLogEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (ShiftLogEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftLogEntry>) -> Void) {
        let now = Date()
        let snapshot = loadSnapshot()
        var dates = [now]
        dates.append(contentsOf: snapshot?.scheduledShifts
            .flatMap { [$0.start, $0.end] }
            .filter { $0 > now }
            .prefix(12) ?? [])
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) {
            dates.append(tomorrow)
        }
        let entries = Array(Set(dates)).sorted().map { entry(at: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(6 * 3_600))))
    }

    private func entry(at date: Date, snapshot: WidgetSnapshot? = nil) -> ShiftLogEntry {
        let snapshot = snapshot ?? loadSnapshot()
        let shifts = snapshot?.scheduledShifts ?? []
        let next = shifts.first { $0.end > date }
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: date)
        let weekly = shifts.filter { shift in
            guard let week else { return false }
            return shift.start < week.end && shift.end > week.start
        }
        return ShiftLogEntry(
            date: date,
            localeCode: snapshot?.localeCode ?? "en",
            nextShift: next,
            weeklyMinutes: weekly.reduce(0) { $0 + $1.effectiveMinutes },
            weeklyShiftCount: weekly.count
        )
    }

    private func loadSnapshot() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: ShiftLogWidgetConstants.appGroupIdentifier),
              let data = defaults.data(forKey: ShiftLogWidgetConstants.storageKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

private struct WidgetCopy {
    let localeCode: String

    private var language: String {
        let code = localeCode.lowercased()
        if code.hasPrefix("zh-hant") || code.hasPrefix("zh-tw") || code.hasPrefix("zh-hk") { return "zh-Hant" }
        if code.hasPrefix("zh") { return "zh-Hans" }
        if code.hasPrefix("ja") { return "ja" }
        return "en"
    }

    var nextShift: String { value(zhHans: "下一班", zhHant: "下一班", ja: "次のシフト", en: "Next shift") }
    var noShift: String { value(zhHans: "暂无安排", zhHant: "暫無安排", ja: "予定なし", en: "No shift") }
    var thisWeek: String { value(zhHans: "本周", zhHant: "本週", ja: "今週", en: "This week") }
    var shifts: String { value(zhHans: "个班次", zhHant: "個班次", ja: "件", en: "shifts") }
    var openApp: String { value(zhHans: "打开 App 添加班次", zhHant: "打開 App 新增班次", ja: "Appでシフトを追加", en: "Add a shift in the app") }

    private func value(zhHans: String, zhHant: String, ja: String, en: String) -> String {
        switch language {
        case "zh-Hans": zhHans
        case "zh-Hant": zhHant
        case "ja": ja
        default: en
        }
    }
}

private struct ShiftLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShiftLogEntry

    private var copy: WidgetCopy { WidgetCopy(localeCode: entry.localeCode) }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                accessoryInline
            case .accessoryCircular:
                accessoryCircular
            case .accessoryRectangular:
                accessoryRectangular
            case .systemMedium:
                homeMedium
            default:
                homeSmall
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(hex: entry.nextShift?.colorHex ?? "315C8C").opacity(0.22), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var accessoryInline: some View {
        Label {
            if let shift = entry.nextShift {
                Text("\(shift.jobName) \(shift.start, style: .time)")
            } else {
                Text(copy.noShift)
            }
        } icon: {
            Image(systemName: "calendar.badge.clock")
        }
        .privacySensitive()
    }

    private var accessoryCircular: some View {
        VStack(spacing: 1) {
            Image(systemName: "calendar.badge.clock")
            if let shift = entry.nextShift {
                Text(shift.start, style: .time).font(.caption2.bold()).minimumScaleFactor(0.65)
            } else {
                Text("--").font(.caption.bold())
            }
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(copy.nextShift).font(.caption2).foregroundStyle(.secondary)
            if let shift = entry.nextShift {
                Text(shift.jobName).font(.headline).lineLimit(1).privacySensitive()
                Text(shift.start...shift.end).font(.caption2).privacySensitive()
            } else {
                Text(copy.noShift).font(.headline)
            }
        }
    }

    private var homeSmall: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(copy.nextShift, systemImage: "calendar.badge.clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let shift = entry.nextShift {
                Text(shift.jobName).font(.headline).lineLimit(2).privacySensitive()
                Text(shift.start, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.title3.bold())
                    .privacySensitive()
                Text(shift.start...shift.end).font(.caption2).foregroundStyle(.secondary).privacySensitive()
            } else {
                Text(copy.noShift).font(.title3.bold())
                Text(copy.openApp).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(copy.thisWeek) · \(duration(entry.weeklyMinutes))")
                .font(.caption.weight(.medium))
                .privacySensitive()
        }
    }

    private var homeMedium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Label(copy.nextShift, systemImage: "calendar.badge.clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let shift = entry.nextShift {
                    Text(shift.jobName).font(.title3.bold()).lineLimit(2).privacySensitive()
                    Text(shift.start, format: .dateTime.weekday(.wide).month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shift.start...shift.end).font(.headline).privacySensitive()
                } else {
                    Text(copy.noShift).font(.title3.bold())
                    Text(copy.openApp).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text(copy.thisWeek).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(duration(entry.weeklyMinutes)).font(.title2.bold().monospacedDigit()).privacySensitive()
                Text("\(entry.weeklyShiftCount) \(copy.shifts)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .privacySensitive()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

struct ShiftLogSummaryWidget: Widget {
    let kind = ShiftLogWidgetConstants.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShiftLogProvider()) { entry in
            ShiftLogWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget.displayName"))
        .description(LocalizedStringKey("widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ShiftLogWidgets: WidgetBundle {
    var body: some Widget {
        ShiftLogSummaryWidget()
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x315C8C
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}
