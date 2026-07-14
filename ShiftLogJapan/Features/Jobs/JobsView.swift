import SwiftUI
import SwiftData

struct JobsView: View {
    @Query(sort: \Job.createdAt) private var jobs: [Job]
    @Query private var rates: [WageRate]
    @State private var editingJob: Job?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if jobs.isEmpty {
                    ContentUnavailableView("job.empty", systemImage: "briefcase", description: Text("job.empty.description"))
                } else {
                    List {
                        ForEach(jobs) { job in
                            Button { editingJob = job } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(hex: job.colorHex))
                                        .frame(width: 44, height: 44)
                                        .overlay(Image(systemName: "briefcase.fill").foregroundStyle(.white))
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(job.displayName).font(.headline)
                                            if !job.isActive { Text("job.inactive").font(.caption).foregroundStyle(.secondary) }
                                        }
                                        Text(job.employerName.isEmpty ? job.locationName : job.employerName).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(CurrencyFormatter.string(currentRate(job.id))).font(.subheadline.monospacedDigit())
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("tab.jobs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("job.add")
                        .accessibilityIdentifier("job.add")
                }
            }
            .sheet(isPresented: $showingNew) { JobEditorView() }
            .sheet(item: $editingJob) { JobEditorView(job: $0) }
        }
    }

    private func currentRate(_ jobID: UUID) -> Decimal {
        ModelAdapters.wageRate(for: jobID, on: Date(), rates: rates)
    }
}

struct JobEditorView: View {
    private enum FieldID {
        static let name = "job.field.name"
        static let wage = "job.field.wage"
        static let errorSummary = "job.form.errorSummary"
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var rates: [WageRate]
    @Query private var rules: [PremiumRule]
    let job: Job?

    @State private var name = ""
    @State private var employer = ""
    @State private var location = ""
    @State private var address = ""
    @State private var colorHex = AppTheme.palette[0]
    @State private var hourlyText = "1,200"
    @State private var startHour = 9
    @State private var endHour = 17
    @State private var breakMinutes = 60
    @State private var transportKind = TransportKind.none
    @State private var transport = 0
    @State private var roundingInterval = 1
    @State private var roundingDirection = RoundingDirection.nearest
    @State private var payClosingDay = 31
    @State private var payDay = 25
    @State private var reminderMinutes = 60
    @State private var calendarSync = false
    @State private var deepNightPremium = true
    @State private var notes = ""
    @State private var isActive = true
    @State private var issues: [FormIssue] = []
    @State private var pendingLargeWage: Decimal?
    @State private var scrollRequest = 0
    @FocusState private var wageFieldFocused: Bool
    @AccessibilityFocusState private var errorSummaryFocused: Bool

    init(job: Job? = nil) {
        self.job = job
        guard let job else { return }
        _name = State(initialValue: job.displayName)
        _employer = State(initialValue: job.employerName)
        _location = State(initialValue: job.locationName)
        _address = State(initialValue: job.address)
        _colorHex = State(initialValue: job.colorHex)
        _startHour = State(initialValue: job.defaultStartHour)
        _endHour = State(initialValue: job.defaultEndHour)
        _breakMinutes = State(initialValue: job.defaultBreakMinutes)
        _transportKind = State(initialValue: job.transportKind)
        _transport = State(initialValue: NSDecimalNumber(decimal: job.transportAmount).intValue)
        _roundingInterval = State(initialValue: job.roundingIntervalMinutes)
        _roundingDirection = State(initialValue: job.roundingDirection)
        _payClosingDay = State(initialValue: job.payClosingDay)
        _payDay = State(initialValue: job.payDay)
        _reminderMinutes = State(initialValue: job.shiftReminderMinutes)
        _calendarSync = State(initialValue: job.calendarSyncEnabled)
        _notes = State(initialValue: job.notes)
        _isActive = State(initialValue: job.isActive)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    if !issues.isEmpty {
                        Section {
                            FormErrorSummary(issues: issues)
                                .accessibilityFocused($errorSummaryFocused)
                        }
                        .id(FieldID.errorSummary)
                    }
                    Section("job.section.basic") {
                        TextField("job.name", text: $name)
                            .accessibilityIdentifier(FieldID.name)
                        if let issue = issue(for: FieldID.name) { InlineFieldError(message: issue.message) }
                        TextField("job.employer", text: $employer)
                        TextField("job.location", text: $location)
                        TextField("job.address", text: $address)
                        HStack {
                            ForEach(AppTheme.palette, id: \.self) { hex in
                                Button { colorHex = hex } label: {
                                    Circle().fill(Color(hex: hex)).frame(width: 30, height: 30).overlay {
                                        if hex == colorHex { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                        Toggle("job.active", isOn: $isActive)
                    }
                    .id(FieldID.name)

                    Section("job.section.wage") {
                        HStack {
                            TextField("job.hourly.placeholder", text: $hourlyText)
                                .keyboardType(.numberPad)
                                .focused($wageFieldFocused)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("job.hourly")
                                .accessibilityIdentifier(FieldID.wage)
                            Text("job.hourly.unit").foregroundStyle(.secondary)
                        }
                        if let issue = issue(for: FieldID.wage) { InlineFieldError(message: issue.message) }
                        Toggle("job.deepNight", isOn: $deepNightPremium)
                        Picker("job.rounding.interval", selection: $roundingInterval) {
                            Text("1 min").tag(1); Text("5 min").tag(5); Text("10 min").tag(10); Text("15 min").tag(15); Text("30 min").tag(30)
                        }
                        Picker("job.rounding.direction", selection: $roundingDirection) {
                            Text("round.down").tag(RoundingDirection.down)
                            Text("round.nearest").tag(RoundingDirection.nearest)
                            Text("round.up").tag(RoundingDirection.up)
                        }
                    }
                    .id(FieldID.wage)

                    Section("job.section.defaults") {
                        Stepper(value: $startHour, in: 0...23) { LabeledContent("shift.start", value: String(format: "%02d:00", startHour)) }
                        Stepper(value: $endHour, in: 0...23) { LabeledContent("shift.end", value: String(format: "%02d:00", endHour)) }
                        Stepper(value: $breakMinutes, in: 0...480, step: 5) { LabeledContent("shift.break", value: "\(breakMinutes) min") }
                    }
                    Section("job.section.transport") {
                        Picker("shift.transport", selection: $transportKind) {
                            Text("transport.none").tag(TransportKind.none)
                            Text("transport.perShift").tag(TransportKind.perShift)
                            Text("transport.manual").tag(TransportKind.manual)
                        }
                        if transportKind == .perShift {
                            Stepper(value: $transport, in: 0...10_000, step: 50) { LabeledContent("shift.transport", value: CurrencyFormatter.string(Decimal(transport))) }
                        }
                    }
                    Section("job.section.pay") {
                        Stepper(value: $payClosingDay, in: 1...31) { LabeledContent("job.closingDay", value: "\(payClosingDay)") }
                        Stepper(value: $payDay, in: 1...31) { LabeledContent("job.payDay", value: "\(payDay)") }
                    }
                    Section("job.section.system") {
                        Stepper(value: $reminderMinutes, in: 0...1_440, step: 15) { LabeledContent("job.reminder", value: "\(reminderMinutes) min") }
                        Toggle("job.calendarSync", isOn: $calendarSync)
                    }
                    Section("shift.notes") { TextField("shift.notes.placeholder", text: $notes, axis: .vertical) }
                }
                .onChange(of: scrollRequest) { _, _ in
                    withAnimation { proxy.scrollTo(FieldID.errorSummary, anchor: .top) }
                    errorSummaryFocused = true
                }
            }
            .navigationTitle(job == nil ? "job.add" : "job.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("common.save") { validateAndSave() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done") { wageFieldFocused = false; formatWageIfValid() }
                }
            }
            .onAppear {
                if let job {
                    let current = ModelAdapters.wageRate(for: job.id, on: Date(), rates: rates)
                    hourlyText = WageInputParser.formatJPY(current)
                    deepNightPremium = rules.contains { $0.jobID == job.id && $0.name == "Deep Night 22:00–05:00" && $0.enabled && $0.effectiveTo == nil }
                }
            }
            .onChange(of: name) { _, _ in clearResolvedIssues() }
            .onChange(of: hourlyText) { _, _ in clearResolvedIssues() }
            .onChange(of: wageFieldFocused) { _, focused in if !focused { formatWageIfValid() } }
            .alert("job.hourly.large.title", isPresented: Binding(get: { pendingLargeWage != nil }, set: { if !$0 { pendingLargeWage = nil } })) {
                Button("common.cancel", role: .cancel) { pendingLargeWage = nil }
                Button("job.hourly.large.confirm") {
                    if let amount = pendingLargeWage { pendingLargeWage = nil; persist(hourlyAmount: amount) }
                }
            } message: { Text("job.hourly.large.message") }
        }
    }

    private func issue(for fieldID: String) -> FormIssue? { issues.first { $0.fieldID == fieldID } }

    private func clearResolvedIssues() {
        issues.removeAll { issue in
            switch issue.id {
            case "job.name.required": return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case "job.wage.invalid": return (try? WageInputParser.parseJPY(hourlyText)) != nil
            default: return false
            }
        }
    }

    private func validateAndSave() {
        wageFieldFocused = false
        var problems: [FormIssue] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append(FormIssue("job.name.required", message: String(localized: "error.job.name.required"), fieldID: FieldID.name))
        }
        let amount: Decimal
        do { amount = try WageInputParser.parseJPY(hourlyText) }
        catch {
            problems.append(FormIssue("job.wage.invalid", message: wageErrorMessage(error), fieldID: FieldID.wage))
            amount = 0
        }
        guard problems.isEmpty else { present(problems); return }
        if amount > 100_000 {
            pendingLargeWage = amount
            return
        }
        persist(hourlyAmount: amount)
    }

    private func wageErrorMessage(_ error: Error) -> String {
        switch error as? WageInputError {
        case .empty: String(localized: "error.job.wage.required")
        case .nonPositive: String(localized: "error.job.wage.positive")
        default: String(localized: "error.job.wage.invalid")
        }
    }

    private func present(_ newIssues: [FormIssue]) {
        issues = newIssues
        scrollRequest += 1
    }

    private func formatWageIfValid() {
        guard let amount = try? WageInputParser.parseJPY(hourlyText) else { return }
        hourlyText = WageInputParser.formatJPY(amount)
    }

    private func persist(hourlyAmount: Decimal) {
        let target = job ?? Job(displayName: name, hourlyAmount: hourlyAmount, colorHex: colorHex)
        if job == nil { context.insert(target) }
        target.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.employerName = employer
        target.locationName = location
        target.address = address
        target.colorHex = colorHex
        target.defaultStartHour = startHour
        target.defaultEndHour = endHour
        target.defaultBreakMinutes = breakMinutes
        target.transportKindRaw = transportKind.rawValue
        target.transportAmount = Decimal(transport)
        target.roundingIntervalMinutes = roundingInterval
        target.roundingDirectionRaw = roundingDirection.rawValue
        target.payClosingDay = payClosingDay
        target.payDay = payDay
        target.shiftReminderMinutes = reminderMinutes
        target.calendarSyncEnabled = calendarSync
        target.notes = notes
        target.isActive = isActive
        target.updatedAt = Date()

        let current = rates.filter { $0.jobID == target.id && $0.effectiveTo == nil }.sorted { $0.effectiveFrom > $1.effectiveFrom }.first
        if current?.hourlyAmount != hourlyAmount {
            current?.effectiveTo = Date()
            context.insert(WageRate(jobID: target.id, hourlyAmount: hourlyAmount, effectiveFrom: Date()))
        } else if current == nil {
            context.insert(WageRate(jobID: target.id, hourlyAmount: hourlyAmount))
        }

        let deepNight = rules.first { $0.jobID == target.id && $0.name == "Deep Night 22:00–05:00" && $0.effectiveTo == nil }
        if deepNightPremium {
            if let deepNight { deepNight.enabled = true }
            else {
                let rule = PremiumRule(jobID: target.id, name: "Deep Night 22:00–05:00", percentage: Decimal(string: "0.25")!)
                rule.startMinutesFromMidnight = 22 * 60
                rule.endMinutesFromMidnight = 5 * 60
                rule.stackable = true
                rule.priority = 100
                context.insert(rule)
            }
        } else {
            deepNight?.effectiveTo = Date()
        }
        do { try context.save(); dismiss() }
        catch { present([FormIssue("save.failed", message: String(format: String(localized: "error.save.failed"), error.localizedDescription))]) }
    }
}
