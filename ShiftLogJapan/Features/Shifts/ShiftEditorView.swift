import SwiftUI
import SwiftData

private struct BreakDraft: Identifiable, Equatable {
    var id = UUID()
    var start: Date
    var end: Date

    var interval: BreakInterval { BreakInterval(start: start, end: end) }
}

struct ShiftEditorView: View {
    private enum FieldID {
        static let job = "shift.field.job"
        static let schedule = "shift.field.schedule"
        static let actual = "shift.field.actual"
        static let errorSummary = "shift.form.errorSummary"
    }

    private enum ConfirmationKind {
        case overnight, saveSeries, deleteSeries
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
    @State private var scheduledBreakDrafts: [BreakDraft] = []
    @State private var actualConfirmed = false
    @State private var actualStart: Date
    @State private var actualEnd: Date
    @State private var actualBreakDrafts: [BreakDraft] = []
    @State private var transportAmount = 0
    @State private var bonusAmount = 0
    @State private var deductionAmount = 0
    @State private var notes = ""
    @State private var repeatCount = 1
    @State private var issues: [FormIssue] = []
    @State private var conflictShift: Shift?
    @State private var riskMessage: String?
    @State private var showingCopy = false
    @State private var viewingConflict: Shift?
    @State private var confirmationKind: ConfirmationKind?
    @State private var showingConfirmation = false
    @State private var showingDeleteAlert = false
    @State private var schedulePickerRevision = 0
    @State private var syncingDates = false
    @State private var isHydrating = true
    @State private var didHydrate = false
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
            editorPresented
        }
    }

    private var editorChrome: some View {
        editorScrollContainer
            .navigationTitle(shift == nil ? "shift.add" : "shift.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("common.save") { validateAndSave() } }
            }
            .onAppear { hydrateDefaults() }
    }

    private var editorObservedSchedule: some View {
        editorChrome
            .onChange(of: crossDayEnabled) { _, enabled in handleCrossDayChange(enabled) }
            .onChange(of: jobID) { oldValue, newValue in
                clearResolvedIssues()
                guard oldValue != newValue, !isHydrating, shift == nil,
                      let newValue, let job = jobs.first(where: { $0.id == newValue }) else { return }
                applyJobDefaults(job)
            }
            .onChange(of: status) { _, _ in clearResolvedIssues() }
            .onChange(of: scheduledBreakDrafts) { _, _ in clearResolvedIssues() }
    }

    private var editorObservedActual: some View {
        editorObservedSchedule
            .onChange(of: actualConfirmed) { _, _ in clearResolvedIssues() }
            .onChange(of: actualStart) { _, _ in clearResolvedIssues() }
            .onChange(of: actualEnd) { _, _ in clearResolvedIssues() }
            .onChange(of: actualBreakDrafts) { _, _ in clearResolvedIssues() }
    }

    private var editorAlerts: some View {
        editorObservedActual
            .alert("risk.title", isPresented: riskAlertPresented) {
                Button("common.back", role: .cancel) { riskMessage = nil }
                Button("risk.saveAnyway") { riskMessage = nil; requestPersist() }
            } message: { Text(riskMessage ?? "") }
            .confirmationDialog(confirmationTitle, isPresented: $showingConfirmation, titleVisibility: .visible) {
                confirmationActions
            }
            .onChange(of: showingConfirmation) { wasShowing, isShowing in
                if wasShowing, !isShowing, confirmationKind == .overnight { resetSchedulePickers() }
            }
    }

    private var editorPresented: some View {
        editorAlerts
            .sheet(isPresented: $showingCopy) { ShiftEditorView(shift: shift, copying: true) }
            .sheet(item: $viewingConflict) { ShiftEditorView(shift: $0) }
    }

    private var confirmationTitle: LocalizedStringKey {
        switch confirmationKind {
        case .overnight: "shift.overnight.suggestion"
        case .saveSeries: "shift.series.edit.title"
        case .deleteSeries: "shift.series.delete.title"
        case nil: "common.notice"
        }
    }

    @ViewBuilder private var confirmationActions: some View {
        switch confirmationKind {
        case .overnight:
            Button("shift.overnight.setNextDay") {
                syncingDates = true
                crossDayEnabled = true
                end = ShiftDateLinker.promoteEndToNextDay(start: start, end: end)
                syncingDates = false
                resetSchedulePickers()
                clearResolvedIssues()
            }
            Button("shift.overnight.keepSameDay", role: .cancel) { resetSchedulePickers() }
        case .saveSeries:
            Button("shift.series.this") { persist(scope: .thisOccurrence) }
            Button("shift.series.future") { persist(scope: .thisAndFuture) }
            Button("shift.series.all") { persist(scope: .entireSeries) }
            Button("common.cancel", role: .cancel) {}
        case .deleteSeries:
            Button("shift.series.this", role: .destructive) { deleteShift(scope: .thisOccurrence) }
            Button("shift.series.future", role: .destructive) { deleteShift(scope: .thisAndFuture) }
            Button("shift.series.all", role: .destructive) { deleteShift(scope: .entireSeries) }
            Button("common.cancel", role: .cancel) {}
        case nil:
            EmptyView()
        }
    }

    private func presentConfirmation(_ kind: ConfirmationKind) {
        confirmationKind = kind
        showingConfirmation = true
    }

    private var editorScrollContainer: some View {
        ScrollViewReader { proxy in
            editorForm(proxy: proxy)
                .onChange(of: scrollRequest) { _, _ in
                    withAnimation { proxy.scrollTo(FieldID.errorSummary, anchor: .top) }
                    errorSummaryFocused = true
                }
        }
    }

    private func editorForm(proxy: ScrollViewProxy) -> some View {
        Form {
            errorContent(proxy: proxy)
            if jobs.isEmpty {
                ContentUnavailableView("job.empty", systemImage: "briefcase", description: Text("job.empty.description"))
            }
            scheduleSection
            previewSection
            actualSection
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
                    Button("common.delete", role: .destructive) { requestDelete() }
                        .accessibilityIdentifier("shift.delete")
                        .alert("shift.delete.confirm", isPresented: $showingDeleteAlert) {
                            Button("common.delete", role: .destructive) { deleteShift(scope: .thisOccurrence) }
                                .accessibilityIdentifier("shift.delete.confirmAction")
                            Button("common.cancel", role: .cancel) {}
                        }
                }
            }
        }
    }

    @ViewBuilder private func errorContent(proxy: ScrollViewProxy) -> some View {
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
    }

    private var scheduleSection: some View {
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
                .id("shift.start.\(schedulePickerRevision)")
                .accessibilityIdentifier("shift.start")
            DatePicker("shift.end", selection: linkedEnd)
                .id("shift.end.\(schedulePickerRevision)")
                .accessibilityIdentifier("shift.end")
            if let issue = issue(for: FieldID.schedule) {
                InlineFieldError(message: issue.message)
            } else if let liveConflict = liveConflictShift {
                InlineFieldError(message: conflictDescription(liveConflict))
            }
            breakEditor(
                drafts: $scheduledBreakDrafts,
                rangeStart: start,
                rangeEnd: end,
                prefix: "scheduled",
                onAdd: { scheduledBreakDrafts = appendingBreak(to: scheduledBreakDrafts, rangeStart: start, rangeEnd: end) }
            )
            if shift == nil {
                Stepper(value: $repeatCount, in: 1...52) {
                    LabeledContent("shift.repeat", value: repeatLabel)
                }
            }
        }
        .id(FieldID.schedule)
    }

    @ViewBuilder private var previewSection: some View {
        if let preview = livePreview {
            Section("shift.preview") {
                LabeledContent("earnings.hours", value: DurationFormatter.string(minutes: preview.effectiveMinutes))
                LabeledContent("earnings.estimated", value: CurrencyFormatter.string(preview.total))
            }
        }
    }

    private var actualSection: some View {
        Section("shift.section.actual") {
            Toggle("shift.actual.confirmed", isOn: $actualConfirmed)
            if actualConfirmed {
                DatePicker("shift.actual.start", selection: linkedActualStart)
                DatePicker("shift.actual.end", selection: $actualEnd)
                if let issue = issue(for: FieldID.actual) { InlineFieldError(message: issue.message) }
                breakEditor(
                    drafts: $actualBreakDrafts,
                    rangeStart: actualStart,
                    rangeEnd: actualEnd,
                    prefix: "actual",
                    onAdd: { actualBreakDrafts = appendingBreak(to: actualBreakDrafts, rangeStart: actualStart, rangeEnd: actualEnd) }
                )
            }
        }
        .id(FieldID.actual)
    }

    private var repeatLabel: String {
        repeatCount == 1
            ? String(localized: "shift.repeat.none")
            : String(format: String(localized: "shift.repeat.weeks"), repeatCount)
    }

    private var liveConflictShift: Shift? {
        guard let jobID, end > start, status != .cancelled else { return nil }
        let proposed = ShiftInterval(id: shift?.id ?? UUID(), jobID: jobID, start: start, end: end, breakMinutes: scheduledBreakMinutes, breaks: scheduledBreaks, isCancelled: false)
        let existing = existingIntervals
        guard let conflict = ConflictDetector.firstConflict(for: proposed, among: existing) else { return nil }
        return allShifts.first { $0.id == conflict.existingID }
    }

    private var riskAlertPresented: Binding<Bool> {
        Binding(
            get: { riskMessage != nil },
            set: { value in if !value { riskMessage = nil } }
        )
    }

    private var linkedStart: Binding<Date> {
        Binding(
            get: { start },
            set: { newValue in
                let delta = newValue.timeIntervalSince(start)
                start = newValue
                shiftBreakDrafts(&scheduledBreakDrafts, by: delta)
                if !crossDayEnabled {
                    end = ShiftDateLinker.afterStartChange(start: newValue, end: end, crossDayEnabled: false).end
                }
                clearResolvedIssues()
                offerOvernightIfNeeded()
            }
        )
    }

    private var linkedActualStart: Binding<Date> {
        Binding(
            get: { actualStart },
            set: { newValue in
                let delta = newValue.timeIntervalSince(actualStart)
                actualStart = newValue
                shiftBreakDrafts(&actualBreakDrafts, by: delta)
                clearResolvedIssues()
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
            breaks: scheduledBreaks,
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

    private var scheduledBreaks: [BreakInterval] {
        scheduledBreakDrafts.map(\.interval).sorted { $0.start < $1.start }
    }

    private var actualBreaks: [BreakInterval] {
        actualBreakDrafts.map(\.interval).sorted { $0.start < $1.start }
    }

    private var scheduledBreakMinutes: Int {
        scheduledBreaks.reduce(0) { $0 + max(0, Int($1.end.timeIntervalSince($1.start) / 60)) }
    }

    private func issue(for fieldID: String) -> FormIssue? { issues.first { $0.fieldID == fieldID } }

    private func moneyStepper(_ key: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...100_000, step: 50) {
            LabeledContent(String(localized: String.LocalizationValue(key)), value: CurrencyFormatter.string(Decimal(value.wrappedValue)))
        }
    }

    private func breakEditor(
        drafts: Binding<[BreakDraft]>,
        rangeStart: Date,
        rangeEnd: Date,
        prefix: String,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(drafts.wrappedValue.enumerated()), id: \.element.id) { index, draft in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(format: String(localized: "shift.break.number"), index + 1)).font(.subheadline.bold())
                        Spacer()
                        Button(role: .destructive) {
                            var updated = drafts.wrappedValue
                            updated.removeAll { $0.id == draft.id }
                            drafts.wrappedValue = updated
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("common.delete")
                    }
                    DatePicker(
                        "shift.break.start",
                        selection: Binding(
                            get: { drafts.wrappedValue.first(where: { $0.id == draft.id })?.start ?? draft.start },
                            set: { newValue in
                                var updated = drafts.wrappedValue
                                guard let target = updated.firstIndex(where: { $0.id == draft.id }) else { return }
                                updated[target].start = newValue
                                drafts.wrappedValue = updated
                            }
                        ),
                        in: rangeStart...rangeEnd
                    )
                    DatePicker(
                        "shift.break.end",
                        selection: Binding(
                            get: { drafts.wrappedValue.first(where: { $0.id == draft.id })?.end ?? draft.end },
                            set: { newValue in
                                var updated = drafts.wrappedValue
                                guard let target = updated.firstIndex(where: { $0.id == draft.id }) else { return }
                                updated[target].end = newValue
                                drafts.wrappedValue = updated
                            }
                        ),
                        in: rangeStart...rangeEnd
                    )
                }
                .accessibilityIdentifier("shift.break.\(prefix).\(index)")
            }
            Button(action: onAdd) {
                Label("shift.break.add", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("shift.break.add.\(prefix)")
            LabeledContent("shift.break.total", value: DurationFormatter.string(minutes: totalBreakMinutes(drafts.wrappedValue)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func appendingBreak(to drafts: [BreakDraft], rangeStart: Date, rangeEnd: Date) -> [BreakDraft] {
        guard rangeEnd.timeIntervalSince(rangeStart) >= 15 * 60 else { return drafts }
        let duration = min(30 * 60, rangeEnd.timeIntervalSince(rangeStart))
        let sorted = drafts.sorted { $0.end < $1.end }
        let proposedStart = sorted.last?.end.addingTimeInterval(15 * 60)
            ?? rangeStart.addingTimeInterval(max(0, (rangeEnd.timeIntervalSince(rangeStart) - duration) / 2))
        let start = min(proposedStart, rangeEnd.addingTimeInterval(-duration))
        var updated = drafts
        updated.append(BreakDraft(start: start, end: start.addingTimeInterval(duration)))
        return updated
    }

    private func totalBreakMinutes(_ drafts: [BreakDraft]) -> Int {
        drafts.reduce(0) { $0 + max(0, Int($1.end.timeIntervalSince($1.start) / 60)) }
    }

    private func breakDrafts(shiftID: UUID, actual: Bool) -> [BreakDraft] {
        allBreaks
            .filter { $0.shiftID == shiftID && $0.isActual == actual }
            .sorted { $0.start < $1.start }
            .map { BreakDraft(id: $0.id, start: $0.start, end: $0.end) }
    }

    private func shiftBreakDrafts(_ drafts: inout [BreakDraft], by interval: TimeInterval) {
        guard interval != 0 else { return }
        for index in drafts.indices {
            drafts[index].start = drafts[index].start.addingTimeInterval(interval)
            drafts[index].end = drafts[index].end.addingTimeInterval(interval)
        }
    }

    private func hydrateDefaults() {
        guard !didHydrate else { return }
        didHydrate = true
        syncingDates = true
        if jobID == nil, let first = jobs.first(where: \.isActive) {
            jobID = first.id
            applyJobDefaults(first)
        }
        if let shift {
            scheduledBreakDrafts = breakDrafts(shiftID: shift.id, actual: false)
            actualBreakDrafts = breakDrafts(shiftID: shift.id, actual: true)
        } else {
            actualStart = start
            actualEnd = end
            actualBreakDrafts = scheduledBreakDrafts
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
        if !crossDayEnabled, end <= start, !showingConfirmation { presentConfirmation(.overnight) }
    }

    private func applyJobDefaults(_ job: Job) {
        let wasSyncingDates = syncingDates
        syncingDates = true
        let range = ShiftDateLinker.defaultRange(
            for: start,
            startHour: job.defaultStartHour,
            startMinute: job.defaultStartMinute,
            endHour: job.defaultEndHour,
            endMinute: job.defaultEndMinute
        )
        start = range.start
        end = range.end
        crossDayEnabled = !Calendar.current.isDate(range.start, inSameDayAs: range.end)
        scheduledBreakDrafts = defaultBreakDrafts(start: start, end: end, minutes: job.defaultBreakMinutes)
        transportAmount = NSDecimalNumber(decimal: job.transportKind == .perShift ? job.transportAmount : 0).intValue
        if !actualConfirmed {
            actualStart = start
            actualEnd = end
            actualBreakDrafts = scheduledBreakDrafts
        }
        syncingDates = wasSyncingDates
        resetSchedulePickers()
    }

    private func resetSchedulePickers() {
        schedulePickerRevision += 1
    }

    private func clearResolvedIssues() {
        issues.removeAll { issue in
            switch issue.id {
            case "job.required": return jobID != nil
            case "schedule.invalid": return (try? CalculationEngine.validate(start: start, end: end, breaks: scheduledBreaks)) != nil
            case "shift.conflict": return liveConflictShift == nil
            case "actual.invalid":
                return !actualConfirmed || (try? CalculationEngine.validate(start: actualStart, end: actualEnd, breaks: actualBreaks)) != nil
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
        do { try CalculationEngine.validate(start: start, end: end, breaks: scheduledBreaks) }
        catch { problems.append(FormIssue("schedule.invalid", message: error.localizedDescription, fieldID: FieldID.schedule)) }
        if actualConfirmed {
            do { try CalculationEngine.validate(start: actualStart, end: actualEnd, breaks: actualBreaks) }
            catch { problems.append(FormIssue("actual.invalid", message: error.localizedDescription, fieldID: FieldID.actual)) }
        }
        let proposed = ShiftInterval(id: shift?.id ?? UUID(), jobID: jobID, start: start, end: end, breakMinutes: scheduledBreakMinutes, breaks: scheduledBreaks, isCancelled: status == .cancelled)
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
        requestPersist()
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

    private func requestPersist() {
        if shift?.recurrenceSeriesID != nil { presentConfirmation(.saveSeries) }
        else { persist(scope: .thisOccurrence) }
    }

    private func persist(scope: RecurrenceEditScope) {
        guard let jobID, let job = jobs.first(where: { $0.id == jobID }) else { return }
        if let shift, let seriesID = shift.recurrenceSeriesID {
            persistSeries(source: shift, seriesID: seriesID, scope: scope, jobID: jobID, job: job)
            return
        }
        let seriesID = repeatCount > 1 ? UUID() : nil
        var skipped = 0
        for index in 0..<repeatCount {
            let itemStart = Calendar.current.date(byAdding: .weekOfYear, value: index, to: start)!
            let itemEnd = Calendar.current.date(byAdding: .weekOfYear, value: index, to: end)!
            let target: Shift
            if index == 0, let shift { target = shift }
            else {
                let candidate = ShiftInterval(id: UUID(), jobID: jobID, start: itemStart, end: itemEnd, breakMinutes: scheduledBreakMinutes, isCancelled: status == .cancelled)
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
            replaceBreaks(for: target, occurrenceOffset: itemStart.timeIntervalSince(start))
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

    private func persistSeries(
        source: Shift,
        seriesID: UUID,
        scope: RecurrenceEditScope,
        jobID: UUID,
        job: Job
    ) {
        let series = allShifts.filter { !$0.isDeleted && $0.recurrenceSeriesID == seriesID }
        let occurrences = series.map { RecurrenceOccurrence(id: $0.id, start: $0.scheduledStart) }
        let targetIDs = Set(RecurrenceSeriesEngine.targetIDs(occurrences: occurrences, anchorID: source.id, scope: scope))
        let targets = series.filter { targetIDs.contains($0.id) }
        let outsideIntervals = existingIntervals.filter { !targetIDs.contains($0.id) }
        let originalSourceStart = source.scheduledStart

        for target in targets {
            let offset = target.scheduledStart.timeIntervalSince(originalSourceStart)
            let candidateStart = start.addingTimeInterval(offset)
            let candidateEnd = end.addingTimeInterval(offset)
            let candidateBreaks = scheduledBreaks.map {
                BreakInterval(start: $0.start.addingTimeInterval(offset), end: $0.end.addingTimeInterval(offset))
            }
            do { try CalculationEngine.validate(start: candidateStart, end: candidateEnd, breaks: candidateBreaks) }
            catch {
                present([FormIssue("schedule.invalid", message: error.localizedDescription, fieldID: FieldID.schedule)])
                return
            }
            let candidate = ShiftInterval(
                id: target.id, jobID: jobID, start: candidateStart, end: candidateEnd,
                breakMinutes: scheduledBreakMinutes, breaks: candidateBreaks,
                isCancelled: status == .cancelled
            )
            if let conflict = ConflictDetector.firstConflict(for: candidate, among: outsideIntervals),
               let item = allShifts.first(where: { $0.id == conflict.existingID }) {
                conflictShift = item
                present([FormIssue("shift.conflict", message: conflictDescription(item), fieldID: FieldID.schedule)])
                return
            }
        }

        let splitSeriesID = scope == .thisAndFuture ? UUID() : seriesID
        for target in targets {
            let offset = target.scheduledStart.timeIntervalSince(originalSourceStart)
            target.jobID = jobID
            target.scheduledStart = start.addingTimeInterval(offset)
            target.scheduledEnd = end.addingTimeInterval(offset)
            target.status = status
            target.transportAmount = Decimal(transportAmount)
            target.bonusAmount = Decimal(bonusAmount)
            target.deductionAmount = Decimal(deductionAmount)
            target.notes = notes
            if scope == .thisOccurrence { target.recurrenceSeriesID = nil }
            else if scope == .thisAndFuture { target.recurrenceSeriesID = splitSeriesID }
            target.updatedAt = Date()
            replaceScheduledBreaks(for: target, occurrenceOffset: offset)
            if target.id == source.id {
                target.actualConfirmed = actualConfirmed
                target.actualStart = actualConfirmed ? actualStart : nil
                target.actualEnd = actualConfirmed ? actualEnd : nil
                replaceActualBreaks(for: target, occurrenceOffset: 0)
            }
            if target.id == source.id || !target.actualConfirmed { snapshot(target, job: job) }
            scheduleSystemServices(for: target, job: job)
        }
        do { try context.save(); dismiss() }
        catch { present([FormIssue("save.failed", message: String(format: String(localized: "error.save.failed"), error.localizedDescription))]) }
    }

    private func scheduleSystemServices(for target: Shift, job: Job) {
        let notificationID = target.id
        let notificationStart = target.scheduledStart
        let isCancelled = target.status == .cancelled
        let jobName = job.displayName
        let reminderMinutes = job.shiftReminderMinutes
        let notificationEnd = target.scheduledEnd
        let endReminderEnabled = job.shiftEndReminderEnabled
        Task {
            await NotificationService.shared.scheduleShiftReminder(shiftID: notificationID, start: notificationStart, isCancelled: isCancelled, jobName: jobName, minutesBefore: reminderMinutes)
            await NotificationService.shared.scheduleShiftEndConfirmation(shiftID: notificationID, end: notificationEnd, isCancelled: isCancelled, jobName: jobName, enabled: endReminderEnabled)
        }
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
        let offset = shift.scheduledStart.timeIntervalSince(start)
        let calcBreaks = (useActual ? actualBreaks : scheduledBreaks).map {
            BreakInterval(start: $0.start.addingTimeInterval(offset), end: $0.end.addingTimeInterval(offset))
        }
        let rate = ModelAdapters.wageRate(for: shift.jobID, on: calcStart, rates: rates)
        if let result = try? CalculationEngine.calculate(start: calcStart, end: calcEnd, breaks: calcBreaks, hourlyRate: rate, premiums: ModelAdapters.premiumSpecs(for: shift.jobID, on: calcStart, rules: premiumRules), transport: shift.transportAmount, bonus: shift.bonusAmount, deduction: shift.deductionAmount, roundingInterval: job.roundingIntervalMinutes, roundingDirection: job.roundingDirection, wageRoundingUnit: job.wageRoundingUnit) {
            shift.snapshotHourlyRate = rate
            shift.snapshotBaseWage = result.baseWage
            shift.snapshotPremiumWage = result.premiumWage
            shift.snapshotTotal = result.total
        }
    }

    private func replaceBreaks(for shift: Shift, occurrenceOffset: TimeInterval) {
        replaceScheduledBreaks(for: shift, occurrenceOffset: occurrenceOffset)
        replaceActualBreaks(for: shift, occurrenceOffset: occurrenceOffset)
    }

    private func replaceScheduledBreaks(for shift: Shift, occurrenceOffset: TimeInterval) {
        allBreaks.filter { $0.shiftID == shift.id && !$0.isActual }.forEach(context.delete)
        scheduledBreaks.forEach {
            context.insert(ShiftBreak(shiftID: shift.id, isActual: false, start: $0.start.addingTimeInterval(occurrenceOffset), end: $0.end.addingTimeInterval(occurrenceOffset)))
        }
    }

    private func replaceActualBreaks(for shift: Shift, occurrenceOffset: TimeInterval) {
        allBreaks.filter { $0.shiftID == shift.id && $0.isActual }.forEach(context.delete)
        if shift.actualStart != nil, shift.actualEnd != nil {
            actualBreaks.forEach {
                context.insert(ShiftBreak(shiftID: shift.id, isActual: true, start: $0.start.addingTimeInterval(occurrenceOffset), end: $0.end.addingTimeInterval(occurrenceOffset)))
            }
        }
    }

    private func defaultBreakDrafts(start: Date, end: Date, minutes: Int) -> [BreakDraft] {
        guard minutes > 0, end > start else { return [] }
        let duration = end.timeIntervalSince(start)
        let breakDuration = min(Double(minutes * 60), max(0, duration - 60))
        guard breakDuration > 0 else { return [] }
        let breakStart = start.addingTimeInterval((duration - breakDuration) / 2)
        return [BreakDraft(start: breakStart, end: breakStart.addingTimeInterval(breakDuration))]
    }

    private func breakDuration(shiftID: UUID, actual: Bool) -> Int {
        allBreaks.filter { $0.shiftID == shiftID && $0.isActual == actual }.reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
    }

    private func requestDelete() {
        if shift?.recurrenceSeriesID != nil { presentConfirmation(.deleteSeries) }
        else { showingDeleteAlert = true }
    }

    private func deleteShift(scope: RecurrenceEditScope) {
        guard let shift else { return }
        let targets: [Shift]
        if let seriesID = shift.recurrenceSeriesID {
            let series = allShifts.filter { !$0.isDeleted && $0.recurrenceSeriesID == seriesID }
            let occurrences = series.map { RecurrenceOccurrence(id: $0.id, start: $0.scheduledStart) }
            let ids = Set(RecurrenceSeriesEngine.targetIDs(occurrences: occurrences, anchorID: shift.id, scope: scope))
            targets = series.filter { ids.contains($0.id) }
        } else {
            targets = [shift]
        }
        for target in targets {
            let targetID = target.id
            let eventID = target.calendarEventID
            allBreaks.filter { $0.shiftID == targetID }.forEach(context.delete)
            Task { await NotificationService.shared.cancelShiftReminder(shiftID: targetID) }
            if let eventID { try? CalendarService.shared.delete(eventIdentifier: eventID) }
            context.delete(target)
        }
        do { try context.save(); dismiss() }
        catch { present([FormIssue("delete.failed", message: String(format: String(localized: "error.save.failed"), error.localizedDescription))]) }
    }
}
