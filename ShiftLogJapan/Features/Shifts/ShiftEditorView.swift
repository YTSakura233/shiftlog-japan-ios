import SwiftUI
import SwiftData

struct ShiftEditorView: View {
    private enum FieldID {
        static let job = "shift.field.job"
        static let schedule = "shift.field.schedule"
        static let actual = "shift.field.actual"
        static let errorSummary = "shift.form.errorSummary"
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Query(sort: \Job.createdAt) private var jobs: [Job]
    @Query private var allShifts: [Shift]
    @Query private var allBreaks: [ShiftBreak]
    @Query private var rates: [WageRate]
    @Query private var premiumRules: [PremiumRule]
    @Query private var settings: [UserSettings]

    let shift: Shift?
    @State private var jobID: UUID?
    @State private var status: ShiftStatus = .scheduled
    @State private var start: Date
    @State private var end: Date
    @State private var crossDayEnabled: Bool
    @State private var breakMinutes = 60
    @State private var actualConfirmed = false
    @State private var actualStart: Date
    @State private var actualEnd: Date
    @State private var actualBreakMinutes = 60
    @State private var transportAmount = 0
    @State private var bonusAmount = 0
    @State private var deductionAmount = 0
    @State private var notes = ""
    @State private var repeatCount = 1
    @State private var issues: [FormIssue] = []
    @State private var conflictShift: Shift?
    @State private var riskMessage: String?
    @State private var showingDelete = false
    @State private var showingCopy = false
    @State private var viewingConflict: Shift?
    @State private var showingOvernightSuggestion = false
    @State private var syncingDates = false
    @State private var isHydrating = true
    @State private var scrollRequest = 0
    @AccessibilityFocusState private var errorSummaryFocused: Bool

    init(shift: Shift? = nil, copying: Bool = false, initialDate: Date = Date()) {
        self.shift = copying ? nil : shift
        let calendar = Calendar.current
        let defaultRange = ShiftDateLinker.defaultRange(for: initialDate, calendar: calendar)
        let defaultStart = defaultRange.start
        let defaultEnd = defaultRange.end
        let sourceStart = shift?.scheduledStart ?? defaultStart
        let sourceEnd = shift?.scheduledEnd ?? defaultEnd
        _start = State(initialValue: sourceStart)
        _end = State(initialValue: sourceEnd)
        _actualStart = State(initialValue: shift?.actualStart ?? sourceStart)
        _actualEnd = State(initialValue: shift?.actualEnd ?? sourceEnd)
        _crossDayEnabled = State(initialValue: !calendar.isDate(sourceStart, inSameDayAs: sourceEnd))
        if let shift {
            _jobID = State(initialValue: shift.jobID)
            _status = State(initialValue: shift.status)
            _actualConfirmed = State(initialValue: shift.actualConfirmed)
            _transportAmount = State(initialValue: NSDecimalNumber(decimal: shift.transportAmount).intValue)
            _bonusAmount = State(initialValue: NSDecimalNumber(decimal: shift.bonusAmount).intValue)
            _deductionAmount = State(initialValue: NSDecimalNumber(decimal: shift.deductionAmount).intValue)
            _notes = State(initialValue: shift.notes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    if !issues.isEmpty {
                        Section {
                            FormErrorSummary(issues: issues)
                                .accessibilityFocused($errorSummaryFocused)
                            if let conflictShift {
                                Button { viewingConflict = conflictShift } label: {
                                    Label("error.shift.viewConflict", systemImage: "calendar.badge.exclamationmark")
                                }
                                Button("common.back") { scrollToField(FieldID.schedule, proxy: proxy) }
                            }
                        }
                        .id(FieldID.errorSummary)
                    }
                    if jobs.isEmpty {
                        ContentUnavailableView("job.empty", systemImage: "briefcase", description: Text("job.empty.description"))
                    }
                    Section("shift.section.schedule") {
                        Picker("shift.job", selection: $jobID) {
                            Text("common.choose").tag(nil as UUID?)
                            ForEach(jobs.filter(\.isActive)) { Text($0.displayName).tag(Optional($0.id)) }
                        }
                        .accessibilityIdentifier(FieldID.job)
                        if let issue = issue(for: FieldID.job) { InlineFieldError(message: issue.message) }

                        Picker("shift.status", selection: $status) {
                            ForEach(ShiftStatus.allCases) { Text($0.localizedTitle(locale: locale)).tag($0) }
                        }
                        Toggle("shift.crossDay", isOn: $crossDayEnabled)
                            .accessibilityIdentifier("shift.crossDay")
                        DatePicker("shift.start", selection: linkedStart)
                            .accessibilityIdentifier("shift.start")
                        DatePicker("shift.end", selection: linkedEnd)
                            .accessibilityIdentifier("shift.end")
                        if let issue = issue(for: FieldID.schedule) {
                            InlineFieldError(message: issue.message)
                        } else if let liveConflict = liveConflictShift {
                            InlineFieldError(message: conflictDescription(liveConflict))
                        }
                        Stepper(value: $breakMinutes, in: 0...480, step: 5) {
                            LabeledContent("shift.break", value: "\(breakMinutes) min")
                        }
                        if shift == nil {
                            Stepper(value: $repeatCount, in: 1...52) {
                                LabeledContent("shift.repeat", value: repeatCount == 1 ? String(localized: "shift.repeat.none") : String(format: String(localized: "shift.repeat.weeks"), repeatCount))
                            }
                        }
                    }
                    .id(FieldID.schedule)

                    if let preview = livePreview {
                        Section("shift.preview") {
                            LabeledContent("earnings.hours", value: DurationFormatter.string(minutes: preview.effectiveMinutes))
                            LabeledContent("earnings.estimated", value: CurrencyFormatter.string(preview.total))
                        }
                    }

                    Section("shift.section.actual") {
                        Toggle("shift.actual.confirmed", isOn: $actualConfirmed)
                        if actualConfirmed {
                            DatePicker("shift.actual.start", selection: $actualStart)
                            DatePicker("shift.actual.end", selection: $actualEnd)
                            if let issue = issue(for: FieldID.actual) { InlineFieldError(message: issue.message) }
                            Stepper(value: $actualBreakMinutes, in: 0...480, step: 5) {
                                LabeledContent("shift.break", value: "\(actualBreakMinutes) min")
                            }
                        }
                    }
                    .id(FieldID.actual)

                    Section("shift.section.money") {
                        moneyStepper("shift.transport", value: $transportAmount)
                        moneyStepper("shift.bonus", value: $bonusAmount)
                        moneyStepper("shift.deduction", value: $deductionAmount)
                    }
                    Section("shift.notes") {
                        TextField("shift.notes.placeholder", text: $notes, axis: .vertical).lineLimit(2...6)
                    }
                    if shift != nil {
                        Section {
                            Button { showingCopy = true } label: { Label("common.copy", systemImage: "doc.on.doc") }
                            Button("common.delete", role: .destructive) { showingDelete = true }
                        }
                    }
                }
                .onChange(of: scrollRequest) { _, _ in
                    withAnimation { proxy.scrollTo(FieldID.errorSummary, anchor: .top) }
                    errorSummaryFocused = true
                }
            }
            .navigationTitle(shift == nil ? "shift.add" : "shift.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("common.save") { validateAndSave() } }
            }
            .onAppear { hydrateDefaults() }
            .onChange(of: crossDayEnabled) { _, enabled in handleCrossDayChange(enabled) }
            .onChange(of: jobID) { _, _ in clearResolvedIssues() }
            .onChange(of: status) { _, _ in clearResolvedIssues() }
            .onChange(of: breakMinutes) { _, _ in clearResolvedIssues() }
            .onChange(of: actualConfirmed) { _, _ in clearResolvedIssues() }
            .onChange(of: actualStart) { _, _ in clearResolvedIssues() }
            .onChange(of: actualEnd) { _, _ in clearResolvedIssues() }
            .onChange(of: actualBreakMinutes) { _, _ in clearResolvedIssues() }
            .alert("risk.title", isPresented: Binding(get: { riskMessage != nil }, set: { if !$0 { riskMessage = nil } })) {
                Button("common.back", role: .cancel) { riskMessage = nil }
                Button("risk.saveAnyway") { riskMessage = nil; persist() }
            } message: { Text(riskMessage ?? "") }
            .confirmationDialog("shift.overnight.suggestion", isPresented: $showingOvernightSuggestion, titleVisibility: .visible) {
                Button("shift.overnight.setNextDay") {
                    syncingDates = true
                    crossDayEnabled = true
                    end = ShiftDateLinker.promoteEndToNextDay(start: start, end: end)
                    syncingDates = false
                    clearResolvedIssues()
                }
                Button("shift.overnight.keepSameDay", role: .cancel) {}
            }
            .confirmationDialog("shift.delete.confirm", isPresented: $showingDelete, titleVisibility: .visible) {
                Button("common.delete", role: .destructive) { deleteShift() }
            }
            .sheet(isPresented: $showingCopy) { ShiftEditorView(shift: shift, copying: true) }
            .sheet(item: $viewingConflict) { ShiftEditorView(shift: $0) }
        }
    }

    private var liveConflictShift: Shift? {
        guard let jobID, end > start, status != .cancelled else { return nil }
        let proposed = ShiftInterval(id: shift?.id ?? UUID(), jobID: jobID, start: start, end: end, breakMinutes: breakMinutes, isCancelled: false)
        let existing = existingIntervals
        guard let conflict = ConflictDetector.firstConflict(for: proposed, among: existing) else { return nil }
        return allShifts.first { $0.id == conflict.existingID }
    }

    private var linkedStart: Binding<Date> {
        Binding(
            get: { start },
            set: { newValue in
                start = newValue
                if !crossDayEnabled {
                    end = ShiftDateLinker.afterStartChange(start: newValue, end: end, crossDayEnabled: false).end
                }
                clearResolvedIssues()
                offerOvernightIfNeeded()
            }
        )
    }

    private var linkedEnd: Binding<Date> {
        Binding(
            get: { end },
            set: { newValue in
                end = newValue
                if !crossDayEnabled {
                    start = ShiftDateLinker.afterEndChange(start: start, end: newValue, crossDayEnabled: false).start
                }
                clearResolvedIssues()
                offerOvernightIfNeeded()
            }
        )
    }

    private var livePreview: WageCalculation? {
        guard let jobID, let job = jobs.first(where: { $0.id == jobID }), end > start else { return nil }
        return try? CalculationEngine.calculate(
            start: start,
            end: end,
            breaks: makeBreaks(start: start, end: end, minutes: breakMinutes),
            hourlyRate: ModelAdapters.wageRate(for: jobID, on: start, rates: rates),
            premiums: ModelAdapters.premiumSpecs(for: jobID, on: start, rules: premiumRules),
            transport: Decimal(transportAmount),
            bonus: Decimal(bonusAmount),
            deduction: Decimal(deductionAmount),
            roundingInterval: job.roundingIntervalMinutes,
            roundingDirection: job.roundingDirection,
            wageRoundingUnit: job.wageRoundingUnit
        )
    }

    private var existingIntervals: [ShiftInterval] {
        allShifts.filter { !$0.isDeleted }.map { item in
            let items = allBreaks.filter { $0.shiftID == item.id && !$0.isActual }.map { BreakInterval(start: $0.start, end: $0.end) }
            return ShiftInterval(id: item.id, jobID: item.jobID, start: item.scheduledStart, end: item.scheduledEnd, breakMinutes: breakDuration(shiftID: item.id, actual: false), breaks: items, isCancelled: item.status == .cancelled)
        }
    }

    private func issue(for fieldID: String) -> FormIssue? { issues.first { $0.fieldID == fieldID } }

    private func moneyStepper(_ key: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...100_000, step: 50) {
            LabeledContent(String(localized: String.LocalizationValue(key)), value: CurrencyFormatter.string(Decimal(value.wrappedValue)))
        }
    }

    private func hydrateDefaults() {
        syncingDates = true
        if jobID == nil, let first = jobs.first(where: \.isActive) {
            jobID = first.id
            start = Calendar.current.date(bySettingHour: first.defaultStartHour, minute: first.defaultStartMinute, second: 0, of: start) ?? start
            end = Calendar.current.date(bySettingHour: first.defaultEndHour, minute: first.defaultEndMinute, second: 0, of: start) ?? end
            end = ShiftDateLinker.replacingDay(of: end, with: start)
            breakMinutes = first.defaultBreakMinutes
            transportAmount = NSDecimalNumber(decimal: first.transportKind == .perShift ? first.transportAmount : 0).intValue
        }
        if let shift {
            breakMinutes = breakDuration(shiftID: shift.id, actual: false)
            actualBreakMinutes = breakDuration(shiftID: shift.id, actual: true)
        } else {
            actualStart = start
            actualEnd = end
            actualBreakMinutes = breakMinutes
        }
        syncingDates = false
        Task { @MainActor in await Task.yield(); isHydrating = false }
    }

    private func handleCrossDayChange(_ enabled: Bool) {
        guard !syncingDates, !isHydrating else { return }
        if !enabled {
            syncingDates = true
            let linked = ShiftDateLinker.disablingCrossDay(start: start, end: end)
            end = linked.end
            syncingDates = false
            offerOvernightIfNeeded()
        }
        clearResolvedIssues()
    }

    private func offerOvernightIfNeeded() {
        if !crossDayEnabled, end <= start { showingOvernightSuggestion = true }
    }

    private func clearResolvedIssues() {
        issues.removeAll { issue in
            switch issue.id {
            case "job.required": return jobID != nil
            case "schedule.invalid": return (try? CalculationEngine.validate(start: start, end: end, breaks: makeBreaks(start: start, end: end, minutes: breakMinutes))) != nil
            case "shift.conflict": return liveConflictShift == nil
            case "actual.invalid":
                return !actualConfirmed || (try? CalculationEngine.validate(start: actualStart, end: actualEnd, breaks: makeBreaks(start: actualStart, end: actualEnd, minutes: actualBreakMinutes))) != nil
            default: return false
            }
        }
        if liveConflictShift == nil { conflictShift = nil }
    }

    private func validateAndSave() {
        var problems: [FormIssue] = []
        conflictShift = nil
        guard let jobID else {
            present([FormIssue("job.required", message: String(localized: "error.job.required"), fieldID: FieldID.job)])
            return
        }
        let scheduledBreaks = makeBreaks(start: start, end: end, minutes: breakMinutes)
        do { try CalculationEngine.validate(start: start, end: end, breaks: scheduledBreaks) }
        catch { problems.append(FormIssue("schedule.invalid", message: error.localizedDescription, fieldID: FieldID.schedule)) }
        if actualConfirmed {
            do { try CalculationEngine.validate(start: actualStart, end: actualEnd, breaks: makeBreaks(start: actualStart, end: actualEnd, minutes: actualBreakMinutes)) }
            catch { problems.append(FormIssue("actual.invalid", message: error.localizedDescription, fieldID: FieldID.actual)) }
        }
        let proposed = ShiftInterval(id: shift?.id ?? UUID(), jobID: jobID, start: start, end: end, breakMinutes: breakMinutes, breaks: scheduledBreaks, isCancelled: status == .cancelled)
        if problems.isEmpty,
           let conflict = ConflictDetector.firstConflict(for: proposed, among: existingIntervals),
           let item = allShifts.first(where: { $0.id == conflict.existingID }) {
            conflictShift = item
            problems.append(FormIssue("shift.conflict", message: conflictDescription(item), fieldID: FieldID.schedule))
        }
        guard problems.isEmpty else { present(problems); return }

        if settings.first?.workLimitEnabled == true {
            let intervals = existingIntervals.filter { $0.id != proposed.id } + [proposed]
            let value = settings.first!
            let weekly = WorkLimitEngine.weeklyRisk(containing: start, shifts: intervals, limitMinutes: value.weeklyLimitMinutes, cautionMinutes: value.cautionMinutes, warningMinutes: value.warningMinutes, weekStartDay: value.weekStartDay)
            let rolling = value.rollingSevenDayCheckEnabled ? WorkLimitEngine.rollingSevenDayRisk(endingAt: start, shifts: intervals, limitMinutes: value.weeklyLimitMinutes, cautionMinutes: value.cautionMinutes, warningMinutes: value.warningMinutes) : weekly
            let highest = rolling.level > weekly.level || (rolling.level == weekly.level && rolling.minutes > weekly.minutes) ? rolling : weekly
            if highest.level == .exceeded {
                riskMessage = String(format: String(localized: "risk.save.message"), DurationFormatter.string(minutes: highest.minutes), DurationFormatter.string(minutes: highest.limitMinutes))
                return
            }
        }
        persist()
    }

    private func present(_ newIssues: [FormIssue]) {
        issues = newIssues
        scrollRequest += 1
    }

    private func conflictDescription(_ item: Shift) -> String {
        let name = jobs.first { $0.id == item.jobID }?.displayName ?? String(localized: "job.unknown")
        return String(
            format: String(localized: "error.shift.conflict"),
            name,
            item.scheduledStart.formatted(date: .abbreviated, time: .shortened),
            item.scheduledEnd.formatted(date: .omitted, time: .shortened)
        )
    }

    private func scrollToField(_ fieldID: String, proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo(fieldID, anchor: .center) }
    }

    private func persist() {
        guard let jobID, let job = jobs.first(where: { $0.id == jobID }) else { return }
        let seriesID = repeatCount > 1 ? UUID() : nil
        var skipped = 0
        for index in 0..<repeatCount {
            let itemStart = Calendar.current.date(byAdding: .weekOfYear, value: index, to: start)!
            let itemEnd = Calendar.current.date(byAdding: .weekOfYear, value: index, to: end)!
            let target: Shift
            if index == 0, let shift { target = shift }
            else {
                let candidate = ShiftInterval(id: UUID(), jobID: jobID, start: itemStart, end: itemEnd, breakMinutes: breakMinutes, isCancelled: status == .cancelled)
                if ConflictDetector.firstConflict(for: candidate, among: existingIntervals) != nil { skipped += 1; continue }
                target = Shift(jobID: jobID, scheduledStart: itemStart, scheduledEnd: itemEnd, status: status)
                context.insert(target)
            }
            target.jobID = jobID
            target.scheduledStart = itemStart
            target.scheduledEnd = itemEnd
            target.status = status
            target.actualConfirmed = actualConfirmed
            target.actualStart = actualConfirmed ? Calendar.current.date(byAdding: .weekOfYear, value: index, to: actualStart) : nil
            target.actualEnd = actualConfirmed ? Calendar.current.date(byAdding: .weekOfYear, value: index, to: actualEnd) : nil
            target.transportAmount = Decimal(transportAmount)
            target.bonusAmount = Decimal(bonusAmount)
            target.deductionAmount = Decimal(deductionAmount)
            target.notes = notes
            target.recurrenceSeriesID = seriesID
            target.updatedAt = Date()
            replaceBreaks(for: target, scheduledMinutes: breakMinutes, actualMinutes: actualConfirmed ? actualBreakMinutes : 0)
            snapshot(target, job: job)
            scheduleSystemServices(for: target, job: job)
        }
        do {
            try context.save()
            if skipped > 0 {
                present([FormIssue("repeat.skipped", message: String(format: String(localized: "shift.repeat.skipped"), skipped))])
            } else {
                dismiss()
            }
        } catch {
            present([FormIssue("save.failed", message: String(format: String(localized: "error.save.failed"), error.localizedDescription))])
        }
    }

    private func scheduleSystemServices(for target: Shift, job: Job) {
        let notificationID = target.id
        let notificationStart = target.scheduledStart
        let isCancelled = target.status == .cancelled
        let jobName = job.displayName
        let reminderMinutes = job.shiftReminderMinutes
        Task { await NotificationService.shared.scheduleShiftReminder(shiftID: notificationID, start: notificationStart, isCancelled: isCancelled, jobName: jobName, minutesBefore: reminderMinutes) }
        if job.calendarSyncEnabled {
            Task { @MainActor in
                if isCancelled, let eventID = target.calendarEventID {
                    try? CalendarService.shared.delete(eventIdentifier: eventID)
                    target.calendarEventID = nil
                } else {
                    target.calendarEventID = try? await CalendarService.shared.upsert(shift: target, job: job)
                }
                try? context.save()
            }
        }
    }

    private func snapshot(_ shift: Shift, job: Job) {
        let useActual = shift.actualConfirmed && shift.actualStart != nil && shift.actualEnd != nil
        let calcStart = useActual ? shift.actualStart! : shift.scheduledStart
        let calcEnd = useActual ? shift.actualEnd! : shift.scheduledEnd
        let calcBreaks = makeBreaks(start: calcStart, end: calcEnd, minutes: useActual ? actualBreakMinutes : breakMinutes)
        let rate = ModelAdapters.wageRate(for: shift.jobID, on: calcStart, rates: rates)
        if let result = try? CalculationEngine.calculate(start: calcStart, end: calcEnd, breaks: calcBreaks, hourlyRate: rate, premiums: ModelAdapters.premiumSpecs(for: shift.jobID, on: calcStart, rules: premiumRules), transport: shift.transportAmount, bonus: shift.bonusAmount, deduction: shift.deductionAmount, roundingInterval: job.roundingIntervalMinutes, roundingDirection: job.roundingDirection, wageRoundingUnit: job.wageRoundingUnit) {
            shift.snapshotHourlyRate = rate
            shift.snapshotBaseWage = result.baseWage
            shift.snapshotPremiumWage = result.premiumWage
            shift.snapshotTotal = result.total
        }
    }

    private func replaceBreaks(for shift: Shift, scheduledMinutes: Int, actualMinutes: Int) {
        allBreaks.filter { $0.shiftID == shift.id }.forEach(context.delete)
        makeBreaks(start: shift.scheduledStart, end: shift.scheduledEnd, minutes: scheduledMinutes).forEach {
            context.insert(ShiftBreak(shiftID: shift.id, isActual: false, start: $0.start, end: $0.end))
        }
        if let actualStart = shift.actualStart, let actualEnd = shift.actualEnd {
            makeBreaks(start: actualStart, end: actualEnd, minutes: actualMinutes).forEach {
                context.insert(ShiftBreak(shiftID: shift.id, isActual: true, start: $0.start, end: $0.end))
            }
        }
    }

    private func makeBreaks(start: Date, end: Date, minutes: Int) -> [BreakInterval] {
        guard minutes > 0, end > start else { return [] }
        let duration = end.timeIntervalSince(start)
        let breakDuration = min(Double(minutes * 60), max(0, duration - 60))
        guard breakDuration > 0 else { return [] }
        let breakStart = start.addingTimeInterval((duration - breakDuration) / 2)
        return [BreakInterval(start: breakStart, end: breakStart.addingTimeInterval(breakDuration))]
    }

    private func breakDuration(shiftID: UUID, actual: Bool) -> Int {
        allBreaks.filter { $0.shiftID == shiftID && $0.isActual == actual }.reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
    }

    private func deleteShift() {
        guard let shift else { return }
        shift.isDeleted = true
        shift.updatedAt = Date()
        allBreaks.filter { $0.shiftID == shift.id }.forEach(context.delete)
        Task { await NotificationService.shared.cancelShiftReminder(shiftID: shift.id) }
        if let eventID = shift.calendarEventID { try? CalendarService.shared.delete(eventIdentifier: eventID) }
        do { try context.save(); dismiss() }
        catch { present([FormIssue("delete.failed", message: String(format: String(localized: "error.save.failed"), error.localizedDescription))]) }
    }
}
