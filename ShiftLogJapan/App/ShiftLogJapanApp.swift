import SwiftUI
import SwiftData

@main
struct ShiftLogJapanApp: App {
    private let container: ModelContainer = {
        let schema = Schema([
            UserSettings.self, Job.self, WageRate.self, PremiumRule.self,
            Shift.self, ShiftBreak.self, Payment.self
        ])
        let environment = ProcessInfo.processInfo.environment
        let isUITesting = environment["UITEST_MODE"] == "1"
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            if isUITesting {
                let context = ModelContext(container)
                let settings = UserSettings()
                settings.localeCode = environment["UITEST_LOCALE"] ?? "en"
                settings.disclaimerAcceptedAt = Date()
                settings.onboardingCompleted = true
                context.insert(settings)
                let job = Job(displayName: "UI Test Job", hourlyAmount: 1_200, colorHex: AppTheme.palette[0])
                context.insert(job)
                context.insert(WageRate(jobID: job.id, hourlyAmount: 1_200))
                let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
                let end = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!
                context.insert(Shift(jobID: job.id, scheduledStart: start, scheduledEnd: end))
                try context.save()
            }
            return container
        } catch {
            fatalError("Unable to create local data store: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(container)
    }
}
