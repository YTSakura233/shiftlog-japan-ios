import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [UserSettings]
    @Query private var jobs: [Job]
    @Query private var rates: [WageRate]
    @Query private var rules: [PremiumRule]
    @Query private var shifts: [Shift]
    @Query private var breaks: [ShiftBreak]
    @Query private var payments: [Payment]
    @State private var exportDocument: DataDocument?
    @State private var exportType = UTType.json
    @State private var exportName = "ShiftLog-Backup"
    @State private var exporting = false
    @State private var importing = false
    @State private var message: String?
    @State private var showingDeleteAll = false

    private var settings: UserSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.rules") {
                    Toggle("settings.limit.enabled", isOn: binding(\.workLimitEnabled, default: true))
                    if settings?.workLimitEnabled == true {
                        Stepper(value: binding(\.weeklyLimitMinutes, default: 1_680), in: 60...4_800, step: 60) { LabeledContent("settings.weekly.limit", value: DurationFormatter.string(minutes: settings?.weeklyLimitMinutes ?? 1_680)) }
                        Stepper(value: binding(\.cautionMinutes, default: 1_440), in: 60...(settings?.weeklyLimitMinutes ?? 1_680), step: 60) { LabeledContent("settings.caution", value: DurationFormatter.string(minutes: settings?.cautionMinutes ?? 1_440)) }
                        Stepper(value: binding(\.warningMinutes, default: 1_560), in: 60...(settings?.weeklyLimitMinutes ?? 1_680), step: 60) { LabeledContent("settings.warning", value: DurationFormatter.string(minutes: settings?.warningMinutes ?? 1_560)) }
                        Toggle("settings.rolling", isOn: binding(\.rollingSevenDayCheckEnabled, default: true))
                    }
                    Text("disclaimer.full").font(.caption).foregroundStyle(.secondary)
                }
                Section("settings.language") {
                    Picker("settings.language", selection: binding(\.localeCode, default: "zh-Hans")) {
                        Text("简体中文").tag("zh-Hans"); Text("日本語").tag("ja"); Text("English").tag("en")
                    }
                }
                Section("settings.permissions") {
                    Button { Task { message = await NotificationService.shared.requestAuthorization() ? String(localized: "notification.enabled") : String(localized: "notification.denied") } } label: { Label("settings.notifications", systemImage: "bell") }
                    Button { Task { message = await CalendarService.shared.requestAccess() ? String(localized: "calendar.enabled") : String(localized: "calendar.permission.denied") } } label: { Label("settings.calendar", systemImage: "calendar.badge.plus") }
                    Button { syncCalendar() } label: { Label("settings.calendar.syncNow", systemImage: "arrow.triangle.2.circlepath") }
                }
                Section("settings.data") {
                    Button { exportBackup() } label: { Label("settings.backup.export", systemImage: "square.and.arrow.up") }
                    Button { importing = true } label: { Label("settings.backup.restore", systemImage: "square.and.arrow.down") }
                    Button { exportCSV() } label: { Label("settings.csv", systemImage: "tablecells") }
                    Button { DemoDataService.load(into: context); message = String(localized: "demo.loaded") } label: { Label("settings.demo.load", systemImage: "sparkles") }
                    Button("settings.deleteAll", role: .destructive) { showingDeleteAll = true }
                }
                Section("settings.privacy") {
                    Label("privacy.local", systemImage: "iphone.gen3")
                    Label("privacy.noTracking", systemImage: "hand.raised")
                    Text("privacy.detail").font(.caption).foregroundStyle(.secondary)
                }
                Section("settings.about") {
                    LabeledContent("settings.version", value: "1.0")
                    Link("settings.official.immigration", destination: URL(string: "https://www.moj.go.jp/isa/applications/procedures/shikakugai_00001.html")!)
                    Link("settings.official.labor", destination: URL(string: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/foreign/index.html")!)
                }
            }
            .navigationTitle("tab.me")
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in if case .failure(let error) = result { message = error.localizedDescription } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do { let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; try restore(BackupService.decode(Data(contentsOf: url))); message = String(localized: "backup.restored") }
                catch { message = error.localizedDescription }
            }
            .alert("common.notice", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("common.ok") { message = nil } } message: { Text(message ?? "") }
            .confirmationDialog("settings.delete.confirm", isPresented: $showingDeleteAll, titleVisibility: .visible) { Button("settings.deleteAll", role: .destructive) { deleteAll() } }
        }
    }

    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<UserSettings, T>, default defaultValue: T) -> Binding<T> {
        Binding(get: { settings?[keyPath: keyPath] ?? defaultValue }, set: { value in settings?[keyPath: keyPath] = value; settings?.updatedAt = Date(); try? context.save() })
    }

    private func exportBackup() {
        do { exportDocument = DataDocument(data: try BackupService.encode(settings: settingsList, jobs: jobs, rates: rates, rules: rules, shifts: shifts, breaks: breaks, payments: payments)); exportType = .json; exportName = "ShiftLog-Backup-\(Date().formatted(.iso8601.year().month().day()))"; exporting = true }
        catch { message = error.localizedDescription }
    }

    private func exportCSV() { exportDocument = DataDocument(data: BackupService.csv(jobs: jobs, shifts: shifts, breaks: breaks)); exportType = .commaSeparatedText; exportName = "ShiftLog-Shifts"; exporting = true }

    private func syncCalendar() {
        Task { @MainActor in
            var synced = 0
            for shift in shifts where !shift.isDeleted && shift.status != .cancelled {
                guard let job = jobs.first(where: { $0.id == shift.jobID }), job.calendarSyncEnabled else { continue }
                do { shift.calendarEventID = try await CalendarService.shared.upsert(shift: shift, job: job); synced += 1 } catch { message = error.localizedDescription; return }
            }
            try? context.save(); message = String(format: String(localized: "calendar.synced.count"), synced)
        }
    }

    private func deleteAll() {
        payments.forEach(context.delete); breaks.forEach(context.delete); shifts.forEach(context.delete); rules.forEach(context.delete); rates.forEach(context.delete); jobs.forEach(context.delete)
        settingsList.forEach(context.delete); try? context.save()
    }

    private func restore(_ payload: BackupPayload) throws {
        let currentData = try BackupService.encode(settings: settingsList, jobs: jobs, rates: rates, rules: rules, shifts: shifts, breaks: breaks, payments: payments)
        try saveAutomaticBackup(currentData)
        deleteAll()
        payload.settings.forEach { r in let m = UserSettings(); m.id = r.id; m.localeCode = r.localeCode; m.weekStartDay = r.weekStartDay; m.workLimitEnabled = r.workLimitEnabled; m.weeklyLimitMinutes = r.weeklyLimitMinutes; m.rollingSevenDayCheckEnabled = r.rollingSevenDayCheckEnabled; m.cautionMinutes = r.cautionMinutes; m.warningMinutes = r.warningMinutes; m.disclaimerAcceptedAt = r.disclaimerAcceptedAt; m.onboardingCompleted = r.onboardingCompleted; context.insert(m) }
        payload.jobs.forEach { r in let m = Job(displayName: r.displayName, colorHex: r.colorHex); m.id = r.id; m.employerName = r.employerName; m.locationName = r.locationName; m.address = r.address; m.prefectureCode = r.prefectureCode; m.defaultStartHour = r.defaultStartHour; m.defaultStartMinute = r.defaultStartMinute; m.defaultEndHour = r.defaultEndHour; m.defaultEndMinute = r.defaultEndMinute; m.defaultBreakMinutes = r.defaultBreakMinutes; m.transportKindRaw = r.transportKindRaw; m.transportAmount = r.transportAmount; m.roundingIntervalMinutes = r.roundingIntervalMinutes; m.roundingDirectionRaw = r.roundingDirectionRaw; m.wageRoundingUnit = r.wageRoundingUnit; m.payClosingDay = r.payClosingDay; m.payDay = r.payDay; m.shiftReminderMinutes = r.shiftReminderMinutes; m.calendarSyncEnabled = r.calendarSyncEnabled; m.notes = r.notes; m.isActive = r.isActive; m.createdAt = r.createdAt; m.updatedAt = r.updatedAt; context.insert(m) }
        payload.rates.forEach { r in let m = WageRate(jobID: r.jobID, hourlyAmount: r.hourlyAmount, effectiveFrom: r.effectiveFrom); m.id = r.id; m.effectiveTo = r.effectiveTo; context.insert(m) }
        payload.premiumRules.forEach { r in let m = PremiumRule(jobID: r.jobID, name: r.name, percentage: r.percentage); m.id = r.id; m.kindRaw = r.kindRaw; m.startMinutesFromMidnight = r.startMinutesFromMidnight; m.endMinutesFromMidnight = r.endMinutesFromMidnight; m.weekdaysCSV = r.weekdaysCSV; m.specificDate = r.specificDate; m.fixedHourlyAmount = r.fixedHourlyAmount; m.fixedShiftAmount = r.fixedShiftAmount; m.stackable = r.stackable; m.priority = r.priority; m.effectiveFrom = r.effectiveFrom; m.effectiveTo = r.effectiveTo; m.enabled = r.enabled; context.insert(m) }
        payload.shifts.forEach { r in let m = Shift(jobID: r.jobID, scheduledStart: r.scheduledStart, scheduledEnd: r.scheduledEnd); m.id = r.id; m.statusRaw = r.statusRaw; m.actualStart = r.actualStart; m.actualEnd = r.actualEnd; m.actualConfirmed = r.actualConfirmed; m.transportAmount = r.transportAmount; m.bonusAmount = r.bonusAmount; m.deductionAmount = r.deductionAmount; m.notes = r.notes; m.recurrenceSeriesID = r.recurrenceSeriesID; m.timeZoneIdentifier = r.timeZoneIdentifier; m.snapshotHourlyRate = r.snapshotHourlyRate; m.snapshotBaseWage = r.snapshotBaseWage; m.snapshotPremiumWage = r.snapshotPremiumWage; m.snapshotTotal = r.snapshotTotal; m.createdAt = r.createdAt; m.updatedAt = r.updatedAt; m.isDeleted = r.isDeleted; context.insert(m) }
        payload.breaks.forEach { r in let m = ShiftBreak(shiftID: r.shiftID, isActual: r.isActual, start: r.start, end: r.end); m.id = r.id; context.insert(m) }
        payload.payments.forEach { r in let m = Payment(jobID: r.jobID, periodStart: r.periodStart, periodEnd: r.periodEnd); m.id = r.id; m.estimatedLabor = r.estimatedLabor; m.grossAmount = r.grossAmount; m.deductions = r.deductions; m.transportAmount = r.transportAmount; m.receivedAmount = r.receivedAmount; m.receivedDate = r.receivedDate; m.notes = r.notes; context.insert(m) }
        try context.save()
    }

    private func saveAutomaticBackup(_ data: Data) throws {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = base.appendingPathComponent("AutomaticBackups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("before-restore-\(Date().ISO8601Format()).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
