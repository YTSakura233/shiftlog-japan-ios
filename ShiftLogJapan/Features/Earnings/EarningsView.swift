import SwiftUI
import SwiftData
import Charts

enum EarningsRange: String, CaseIterable, Identifiable {
    case day, week, month, payPeriod, year, custom
    var id: String { rawValue }
    var localizedTitle: String {
        localizedTitle(locale: .current)
    }

    func localizedTitle(locale: Locale) -> String {
        switch self {
        case .day: String(localized: "range.day", defaultValue: "Day", locale: locale)
        case .week: String(localized: "range.week", defaultValue: "Week", locale: locale)
        case .month: String(localized: "range.month", defaultValue: "Month", locale: locale)
        case .payPeriod: String(localized: "range.payPeriod", defaultValue: "Pay period", locale: locale)
        case .year: String(localized: "range.year", defaultValue: "Year", locale: locale)
        case .custom: String(localized: "range.custom", defaultValue: "Custom", locale: locale)
        }
    }
}

enum TimeSource: String, CaseIterable, Identifiable {
    case scheduled, actual
    var id: String { rawValue }
    var localizedTitle: String {
        localizedTitle(locale: .current)
    }

    func localizedTitle(locale: Locale) -> String {
        switch self {
        case .scheduled: String(localized: "source.scheduled", defaultValue: "Scheduled", locale: locale)
        case .actual: String(localized: "source.actual", defaultValue: "Actual", locale: locale)
        }
    }
}

struct EarningsView: View {
    @Environment(\.locale) private var locale
    @Query private var jobs: [Job]
    @Query(sort: \Shift.scheduledStart) private var shifts: [Shift]
    @Query private var breaks: [ShiftBreak]
    @Query private var rates: [WageRate]
    @Query private var premiumRules: [PremiumRule]
    @Query(sort: \Payment.periodStart, order: .reverse) private var payments: [Payment]
    @State private var anchor = Date()
    @State private var range = EarningsRange.month
    @State private var customStart = Date().startOfMonth
    @State private var customEnd = Date()
    @State private var source = TimeSource.scheduled
    @State private var selectedJobID: UUID?
    @State private var showingPayment = false

    private var interval: DateInterval {
        let calendar = Calendar.current
        switch range {
        case .day:
            let start = calendar.startOfDay(for: anchor)
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!)
        case .week: return calendar.dateInterval(of: .weekOfYear, for: anchor)!
        case .month: return DateInterval(start: anchor.startOfMonth, end: anchor.endOfMonth)
        case .payPeriod:
            guard let job = jobs.first(where: { $0.id == selectedJobID }) else {
                return DateInterval(start: anchor.startOfMonth, end: anchor.endOfMonth)
            }
            let period = PayPeriodEngine.period(
                containing: anchor, kind: job.payPeriodKind,
                closingDay: job.payClosingDay, payDay: job.payDay,
                weekStartDay: job.payWeekStartDay, anchor: job.payPeriodAnchor,
                payWeekday: job.payWeekday
            )
            return DateInterval(start: period.start, end: period.end)
        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: anchor))!
            return DateInterval(start: start, end: calendar.date(byAdding: .year, value: 1, to: start)!)
        case .custom: return DateInterval(start: calendar.startOfDay(for: customStart), end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd))!)
        }
    }

    private var calculations: [(Shift, WageCalculation)] {
        shifts.filter { shift in
            !shift.isDeleted && shift.status != .cancelled && shift.scheduledStart < interval.end && shift.scheduledEnd > interval.start && (selectedJobID == nil || shift.jobID == selectedJobID)
        }.compactMap { shift in
            guard shift.status != .absent || source == .scheduled,
                  let job = jobs.first(where: { $0.id == shift.jobID }) else { return nil }
            let useActual = source == .actual
            guard !useActual || shift.actualConfirmed, let start = useActual ? shift.actualStart : shift.scheduledStart, let end = useActual ? shift.actualEnd : shift.scheduledEnd else { return nil }
            let result = try? CalculationEngine.calculate(
                start: start, end: end, breaks: ModelAdapters.breaks(for: shift.id, actual: useActual, all: breaks),
                hourlyRate: ModelAdapters.wageRate(for: shift.jobID, on: start, rates: rates),
                premiums: ModelAdapters.premiumSpecs(for: shift.jobID, on: start, rules: premiumRules),
                transport: shift.transportAmount, bonus: shift.bonusAmount, deduction: shift.deductionAmount,
                roundingInterval: job.roundingIntervalMinutes, roundingDirection: job.roundingDirection,
                wageRoundingUnit: job.wageRoundingUnit
            )
            return result.map { (shift, $0) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    controls
                    totals
                    if !calculations.isEmpty { jobChart; details }
                    else { ContentUnavailableView("earnings.empty", systemImage: "yensign.circle", description: Text("earnings.empty.description")) }
                    paymentsSection
                }.padding()
            }
            .navigationTitle("tab.earnings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingPayment = true } label: { Image(systemName: "plus") }.accessibilityLabel("payment.add") } }
            .sheet(isPresented: $showingPayment) { PaymentEditorView(defaultInterval: interval, selectedJobID: selectedJobID) }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(EarningsRange.allCases) { option in
                        Button {
                            range = option
                            if option == .payPeriod, selectedJobID == nil { selectedJobID = jobs.first?.id }
                        } label: {
                            Text(option.localizedTitle(locale: locale))
                                .font(.subheadline.weight(range == option ? .semibold : .regular))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(range == option ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                                .foregroundStyle(range == option ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(range == option ? .isSelected : [])
                        .accessibilityIdentifier("earnings.range.\(option.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityLabel("earnings.range")
            if range == .custom {
                DatePicker("range.start", selection: $customStart, displayedComponents: .date)
                DatePicker("range.end", selection: $customEnd, in: customStart..., displayedComponents: .date)
            } else {
                HStack { Button { move(-1) } label: { Image(systemName: "chevron.left") }; Spacer(); Text(interval.start.formatted(date: .abbreviated, time: .omitted)).font(.headline); Spacer(); Button { move(1) } label: { Image(systemName: "chevron.right") } }.buttonStyle(.bordered)
            }
            Picker("earnings.source", selection: $source) {
                ForEach(TimeSource.allCases) { Text($0.localizedTitle(locale: locale)).tag($0) }
            }.pickerStyle(.segmented)
            Picker("earnings.job", selection: $selectedJobID) { Text("common.allJobs").tag(nil as UUID?); ForEach(jobs) { Text($0.displayName).tag(Optional($0.id)) } }
        }.appCard()
    }

    private var totals: some View {
        let total = calculations.reduce(Decimal.zero) { $0 + $1.1.total }
        let labor = calculations.reduce(Decimal.zero) { $0 + $1.1.baseWage + $1.1.premiumWage }
        let transport = calculations.reduce(Decimal.zero) { $0 + $1.1.transport }
        let minutes = calculations.reduce(0) { $0 + $1.1.effectiveMinutes }
        return VStack(alignment: .leading, spacing: 12) {
            Text(source == .scheduled ? "earnings.estimated" : "earnings.actualEstimate").font(.caption).foregroundStyle(.secondary)
            Text(CurrencyFormatter.string(total)).font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
            HStack { earningMetric("earnings.labor", CurrencyFormatter.string(labor)); earningMetric("shift.transport", CurrencyFormatter.string(transport)); earningMetric("earnings.hours", DurationFormatter.string(minutes: minutes)) }
            Text("disclaimer.estimate").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).appCard()
    }

    private func earningMetric(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading) { Text(LocalizedStringKey(key)).font(.caption2).foregroundStyle(.secondary); Text(value).font(.subheadline.bold().monospacedDigit()) }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var jobChart: some View {
        let data = jobs.compactMap { job -> (Job, Decimal)? in
            let value = calculations.filter { $0.0.jobID == job.id }.reduce(Decimal.zero) { $0 + $1.1.total }
            return value == 0 ? nil : (job, value)
        }
        return Chart(data, id: \.0.id) { item in
            BarMark(x: .value("Job", item.0.displayName), y: .value("Amount", NSDecimalNumber(decimal: item.1).doubleValue)).foregroundStyle(Color(hex: item.0.colorHex))
        }.frame(height: 180).appCard().accessibilityLabel("earnings.byJob")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("earnings.detail").font(.headline)
            ForEach(calculations, id: \.0.id) { shift, calc in
                VStack(alignment: .leading, spacing: 5) {
                    HStack { Text(jobs.first { $0.id == shift.jobID }?.displayName ?? String(localized: "job.unknown")); Spacer(); Text(CurrencyFormatter.string(calc.total)).font(.headline.monospacedDigit()) }
                    Text(shift.scheduledStart, format: .dateTime.month().day().hour().minute()).font(.subheadline)
                    Text(String(format: String(localized: "earnings.breakdown"), CurrencyFormatter.string(calc.baseWage), CurrencyFormatter.string(calc.premiumWage), CurrencyFormatter.string(calc.transport))).font(.caption).foregroundStyle(.secondary)
                    if !calc.appliedRuleNames.isEmpty { Label(calc.appliedRuleNames.joined(separator: ", "), systemImage: "moon.stars").font(.caption).foregroundStyle(.secondary) }
                }.padding(.vertical, 7)
                Divider()
            }
        }.appCard()
    }

    private var paymentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("payment.records").font(.headline); Spacer(); Button("payment.add") { showingPayment = true } }
            let visible = payments.filter { selectedJobID == nil || $0.jobID == selectedJobID }
            if visible.isEmpty { Text("payment.empty").foregroundStyle(.secondary) }
            ForEach(visible.prefix(6)) { payment in
                HStack {
                    VStack(alignment: .leading) { Text(jobs.first { $0.id == payment.jobID }?.displayName ?? String(localized: "job.unknown")); Text(payment.periodStart...payment.periodEnd).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(payment.receivedAmount.map(CurrencyFormatter.string) ?? "—").font(.headline.monospacedDigit())
                }.padding(.vertical, 5)
            }
        }.appCard()
    }

    private func move(_ amount: Int) {
        if range == .payPeriod {
            anchor = amount < 0 ? interval.start.addingTimeInterval(-1) : interval.end.addingTimeInterval(1)
            return
        }
        let component: Calendar.Component = switch range {
        case .day: .day
        case .week: .weekOfYear
        case .month, .custom, .payPeriod: .month
        case .year: .year
        }
        anchor = Calendar.current.date(byAdding: component, value: amount, to: anchor) ?? anchor
    }
}

struct PaymentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var jobs: [Job]
    @Query private var shifts: [Shift]
    let defaultInterval: DateInterval
    @State private var jobID: UUID?
    @State private var start: Date
    @State private var end: Date
    @State private var gross = 0
    @State private var incomeTax = 0
    @State private var employmentInsurance = 0
    @State private var healthInsurance = 0
    @State private var pension = 0
    @State private var residentTax = 0
    @State private var otherDeductions = 0
    @State private var received = 0
    @State private var receivedDate = Date()
    @State private var notes = ""
    @State private var issues: [FormIssue] = []

    init(defaultInterval: DateInterval, selectedJobID: UUID?) {
        self.defaultInterval = defaultInterval
        _jobID = State(initialValue: selectedJobID); _start = State(initialValue: defaultInterval.start); _end = State(initialValue: defaultInterval.end.addingTimeInterval(-1))
    }

    var body: some View {
        NavigationStack {
            Form {
                if !issues.isEmpty { Section { FormErrorSummary(issues: issues) } }
                Picker("shift.job", selection: $jobID) { Text("common.choose").tag(nil as UUID?); ForEach(jobs) { Text($0.displayName).tag(Optional($0.id)) } }
                if let issue = issues.first(where: { $0.fieldID == "payment.field.job" }) { InlineFieldError(message: issue.message) }
                DatePicker("range.start", selection: $start, displayedComponents: .date)
                DatePicker("range.end", selection: $end, in: start..., displayedComponents: .date)
                Stepper(value: $gross, in: 0...10_000_000, step: 100) { LabeledContent("payment.gross", value: CurrencyFormatter.string(Decimal(gross))) }
                Section("payment.deductions") {
                    moneyStepper("payment.incomeTax", value: $incomeTax)
                    moneyStepper("payment.employmentInsurance", value: $employmentInsurance)
                    moneyStepper("payment.healthInsurance", value: $healthInsurance)
                    moneyStepper("payment.pension", value: $pension)
                    moneyStepper("payment.residentTax", value: $residentTax)
                    moneyStepper("payment.otherDeductions", value: $otherDeductions)
                    LabeledContent("payment.deductions", value: CurrencyFormatter.string(Decimal(totalDeductions)))
                }
                Stepper(value: $received, in: 0...10_000_000, step: 100) { LabeledContent("payment.received", value: CurrencyFormatter.string(Decimal(received))) }
                DatePicker("payment.receivedDate", selection: $receivedDate, displayedComponents: .date)
                TextField("shift.notes", text: $notes, axis: .vertical)
                LabeledContent("payment.estimated", value: CurrencyFormatter.string(estimatedLabor + estimatedTransport))
                LabeledContent("payment.includedShifts", value: "\(includedShifts.count)")
                if gross > 0 { LabeledContent("payment.difference", value: CurrencyFormatter.string(Decimal(received - (gross - totalDeductions)))) }
                Text("disclaimer.payment").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("payment.add").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("common.save") { save() } } }
            .onAppear { if jobID == nil { jobID = jobs.first?.id } }
            .onChange(of: jobID) { _, value in if value != nil { issues.removeAll { $0.fieldID == "payment.field.job" } } }
        }
    }

    private var includedShifts: [Shift] {
        guard let jobID else { return [] }
        let inclusiveEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end)) ?? end
        return shifts.filter {
            !$0.isDeleted && $0.status != .cancelled && $0.jobID == jobID &&
            $0.scheduledStart < inclusiveEnd && $0.scheduledEnd > start
        }
    }

    private var estimatedLabor: Decimal {
        includedShifts.reduce(0) { result, shift in
            result + (shift.snapshotBaseWage ?? 0) + (shift.snapshotPremiumWage ?? 0) + shift.bonusAmount - shift.deductionAmount
        }
    }

    private var estimatedTransport: Decimal {
        includedShifts.reduce(0) { $0 + $1.transportAmount }
    }

    private var totalDeductions: Int {
        incomeTax + employmentInsurance + healthInsurance + pension + residentTax + otherDeductions
    }

    private func moneyStepper(_ key: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...10_000_000, step: 100) {
            LabeledContent(LocalizedStringKey(key), value: CurrencyFormatter.string(Decimal(value.wrappedValue)))
        }
    }

    private func save() {
        guard let jobID else {
            issues = [FormIssue("payment.job.required", message: String(localized: "error.job.required"), fieldID: "payment.field.job")]
            return
        }
        let payment = Payment(jobID: jobID, periodStart: start, periodEnd: end)
        payment.estimatedLabor = estimatedLabor
        payment.transportAmount = estimatedTransport
        payment.grossAmount = Decimal(gross)
        payment.incomeTax = Decimal(incomeTax)
        payment.employmentInsurance = Decimal(employmentInsurance)
        payment.healthInsurance = Decimal(healthInsurance)
        payment.pension = Decimal(pension)
        payment.residentTax = Decimal(residentTax)
        payment.otherDeductions = Decimal(otherDeductions)
        payment.deductions = Decimal(totalDeductions)
        payment.includedShiftIDsCSV = includedShifts.map { $0.id.uuidString }.joined(separator: ",")
        payment.receivedAmount = Decimal(received); payment.receivedDate = receivedDate; payment.notes = notes
        context.insert(payment)
        do { try context.save(); dismiss() }
        catch { issues = [FormIssue("save.failed", message: String(format: String(localized: "error.save.failed"), error.localizedDescription))] }
    }
}
