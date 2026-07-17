import Foundation
import WidgetKit

struct SharedWidgetShift: Codable, Equatable, Sendable {
    let jobName: String
    let start: Date
    let end: Date
    let colorHex: String
    let effectiveMinutes: Int
}

struct SharedWidgetSnapshot: Codable, Equatable, Sendable {
    static let storageKey = "shiftlog.widget.snapshot.v1"

    let generatedAt: Date
    let localeCode: String
    let scheduledShifts: [SharedWidgetShift]
}

@MainActor
enum WidgetSnapshotService {
    static func update(
        jobs: [Job],
        shifts: [Shift],
        breaks: [ShiftBreak],
        localeCode: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let lowerBound = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let upperBound = calendar.date(byAdding: .day, value: 60, to: now) ?? now
        let visibleShifts = shifts.filter {
            !$0.isDeleted && $0.status != .cancelled && $0.status != .absent
                && $0.scheduledEnd > lowerBound && $0.scheduledStart < upperBound
        }
        let jobsByID = Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0) })
        let scheduledShifts = visibleShifts
            .sorted { $0.scheduledStart < $1.scheduledStart }
            .compactMap { shift -> SharedWidgetShift? in
                guard let job = jobsByID[shift.jobID] else { return nil }
                let intervals = ModelAdapters.breaks(for: shift.id, actual: false, all: breaks)
                let minutes = (try? CalculationEngine.effectiveMinutes(
                    start: shift.scheduledStart,
                    end: shift.scheduledEnd,
                    breaks: intervals
                )) ?? 0
                return SharedWidgetShift(
                    jobName: job.displayName,
                    start: shift.scheduledStart,
                    end: shift.scheduledEnd,
                    colorHex: job.colorHex,
                    effectiveMinutes: minutes
                )
            }
        let snapshot = SharedWidgetSnapshot(
            generatedAt: now,
            localeCode: localeCode,
            scheduledShifts: scheduledShifts
        )

        guard let defaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier),
              let data = try? JSONEncoder().encode(snapshot),
              defaults.data(forKey: SharedWidgetSnapshot.storageKey) != data else { return }
        defaults.set(data, forKey: SharedWidgetSnapshot.storageKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ShiftLogSummaryWidget")
    }
}
