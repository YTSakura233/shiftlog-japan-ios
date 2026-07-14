import SwiftUI
import SwiftData

enum CalendarDisplay: String, CaseIterable, Identifiable {
    case month, week, day, year
    var id: String { rawValue }
    var titleKey: String { "calendar.\(rawValue)" }
    var localizedTitle: String {
        localizedTitle(locale: .current)
    }
    func localizedTitle(locale: Locale) -> String {
        switch self {
        case .month: String(localized: "calendar.month", defaultValue: "Month", locale: locale)
        case .week: String(localized: "calendar.week", defaultValue: "Week", locale: locale)
        case .day: String(localized: "calendar.day", defaultValue: "Day", locale: locale)
        case .year: String(localized: "calendar.year", defaultValue: "Year", locale: locale)
        }
    }
}

struct CalendarDashboardView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \Shift.scheduledStart) private var shifts: [Shift]
    @Query private var jobs: [Job]
    @Query private var breaks: [ShiftBreak]
    @Query private var settings: [UserSettings]
    @State private var selectedDate = Date()
    @State private var display: CalendarDisplay = .month
    @State private var editingShift: Shift?
    @State private var showingDayDetail = false

    private var activeShifts: [Shift] { shifts.filter { !$0.isDeleted && $0.status != .cancelled } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    Picker("calendar.view", selection: $display) {
                        ForEach(CalendarDisplay.allCases) { Text($0.localizedTitle(locale: locale)).tag($0) }
                    }.pickerStyle(.segmented)
                    periodHeader
                    switch display {
                    case .month:
                        MonthGridView(month: selectedDate, shifts: activeShifts, jobs: jobs, selectedDate: $selectedDate) { date in
                            selectedDate = date
                            showingDayDetail = true
                        }
                    case .week: weekView
                    case .day: dayView
                    case .year: YearHeatView(year: selectedDate, shifts: activeShifts, breaks: breaks, selectedDate: $selectedDate, display: $display)
                    }
                }.padding()
            }
            .navigationTitle("app.name")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("calendar.today") { selectedDate = Date() } } }
            .sheet(item: $editingShift) { ShiftEditorView(shift: $0) }
            .sheet(isPresented: $showingDayDetail) { DayDetailView(date: selectedDate) }
        }
    }

    private var summary: some View {
        let monthShifts = activeShifts.filter { $0.scheduledStart >= selectedDate.startOfMonth && $0.scheduledStart < selectedDate.endOfMonth }
        let intervals = monthShifts.map(interval(for:))
        let minutes = intervals.reduce(0) { $0 + $1.effectiveMinutes }
        let currentRisk = risk(containing: Date())
        let next = activeShifts.first { $0.scheduledEnd > Date() }
        return VStack(alignment: .leading, spacing: 12) {
            if let next, let job = job(next.jobID) {
                Label("summary.next", systemImage: "clock.badge.checkmark").font(.caption).foregroundStyle(.secondary)
                HStack { Circle().fill(Color(hex: job.colorHex)).frame(width: 10); Text(job.displayName).font(.headline); Spacer(); Text(next.scheduledStart, format: .dateTime.weekday().hour().minute()) }
            } else { Label("summary.noNext", systemImage: "calendar.badge.plus") }
            Divider()
            HStack {
                metric("summary.monthHours", DurationFormatter.string(minutes: minutes))
                metric("summary.workDays", "\(Set(monthShifts.map { Calendar.current.startOfDay(for: $0.scheduledStart) }).count)")
                metric("summary.weekRisk", DurationFormatter.string(minutes: currentRisk.minutes), color: riskColor(currentRisk.level))
            }
            if currentRisk.level != .safe {
                Label(riskText(currentRisk), systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(riskColor(currentRisk.level))
            }
        }.appCard()
    }

    private func metric(_ key: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading) { Text(LocalizedStringKey(key)).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline.monospacedDigit()).foregroundStyle(color) }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodHeader: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(periodTitle).font(.title3.bold())
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right") }
        }.buttonStyle(.bordered)
    }

    private var weekView: some View {
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate)!
        let weekShifts = activeShifts.filter { $0.scheduledStart < interval.end && $0.scheduledEnd > interval.start }
        return VStack(spacing: 10) {
            let currentRisk = risk(containing: selectedDate)
            HStack { metric("summary.scheduled", DurationFormatter.string(minutes: currentRisk.minutes)); metric("summary.remaining", DurationFormatter.string(minutes: currentRisk.remainingMinutes), color: riskColor(currentRisk.level)) }.appCard()
            ForEach(0..<7, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: interval.start)!
                daySection(date, shifts: weekShifts.filter { Calendar.current.isDate($0.scheduledStart, inSameDayAs: date) })
            }
        }
    }

    private var dayView: some View {
        let dayShifts = activeShifts.filter { Calendar.current.isDate($0.scheduledStart, inSameDayAs: selectedDate) }
        return daySection(selectedDate, shifts: dayShifts)
    }

    @ViewBuilder private func daySection(_ date: Date, shifts: [Shift]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date, format: .dateTime.weekday(.wide).month().day()).font(.headline)
            if shifts.isEmpty { ContentUnavailableView("calendar.empty.day", systemImage: "calendar") }
            ForEach(shifts) { shift in
                Button { editingShift = shift } label: { ShiftRow(shift: shift, job: job(shift.jobID), breaks: breaks.filter { $0.shiftID == shift.id }) }.buttonStyle(.plain)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func interval(for shift: Shift) -> ShiftInterval {
        let relevant = breaks.filter { $0.shiftID == shift.id && !$0.isActual }
        let minutes = relevant.reduce(0) { $0 + max(0, Int($1.end.timeIntervalSince($1.start) / 60)) }
        let breakIntervals = relevant.map { BreakInterval(start: $0.start, end: $0.end) }
        return ShiftInterval(id: shift.id, jobID: shift.jobID, start: shift.scheduledStart, end: shift.scheduledEnd, breakMinutes: minutes, breaks: breakIntervals, isCancelled: shift.status == .cancelled)
    }

    private func risk(containing date: Date) -> WorkRisk {
        let value = settings.first ?? UserSettings()
        let intervals = activeShifts.map(interval(for:))
        let weekly = WorkLimitEngine.weeklyRisk(containing: date, shifts: intervals, limitMinutes: value.weeklyLimitMinutes, cautionMinutes: value.cautionMinutes, warningMinutes: value.warningMinutes, weekStartDay: value.weekStartDay)
        guard value.rollingSevenDayCheckEnabled else { return weekly }
        let rolling = WorkLimitEngine.rollingSevenDayRisk(endingAt: date, shifts: intervals, limitMinutes: value.weeklyLimitMinutes, cautionMinutes: value.cautionMinutes, warningMinutes: value.warningMinutes)
        return rolling.level > weekly.level || (rolling.level == weekly.level && rolling.minutes > weekly.minutes) ? rolling : weekly
    }

    private func riskText(_ risk: WorkRisk) -> LocalizedStringKey {
        risk.level == .exceeded ? "risk.exceeded" : "risk.approaching"
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level { case .safe: .green; case .caution: .orange; case .warning: .orange; case .exceeded: .red }
    }

    private func job(_ id: UUID) -> Job? { jobs.first { $0.id == id } }
    private var periodTitle: String {
        switch display {
        case .year: selectedDate.formatted(.dateTime.year())
        case .month: selectedDate.formatted(.dateTime.year().month(.wide))
        case .week: selectedDate.formatted(.dateTime.month().day())
        case .day: selectedDate.formatted(.dateTime.year().month().day())
        }
    }
    private func move(_ amount: Int) {
        let component: Calendar.Component = switch display { case .year: .year; case .month: .month; case .week: .weekOfYear; case .day: .day }
        selectedDate = Calendar.current.date(byAdding: component, value: amount, to: selectedDate) ?? selectedDate
    }
}

struct MonthGridView: View {
    let month: Date
    let shifts: [Shift]
    let jobs: [Job]
    @Binding var selectedDate: Date
    let onSelect: (Date) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let calendar = Calendar.current
        let monthStart = month.startOfMonth
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart)!
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
            ForEach(0..<42, id: \.self) { index in
                let date = calendar.date(byAdding: .day, value: index, to: gridStart)!
                let dayShifts = shifts.filter { calendar.isDate($0.scheduledStart, inSameDayAs: date) }
                let isCurrentMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
                Button { selectedDate = date; onSelect(date) } label: {
                    VStack(spacing: 5) {
                        Text("\(calendar.component(.day, from: date))").font(.subheadline.bold())
                        HStack(spacing: 2) {
                            ForEach(dayShifts.prefix(3)) { shift in Circle().fill(Color(hex: jobs.first { $0.id == shift.jobID }?.colorHex ?? "999999")).frame(width: 6, height: 6) }
                        }
                        Text(dayShifts.isEmpty ? " " : DurationFormatter.string(minutes: dayShifts.reduce(0) { $0 + Int($1.scheduledEnd.timeIntervalSince($1.scheduledStart) / 60) }))
                            .font(.system(size: 8)).lineLimit(1)
                    }
                    .opacity(isCurrentMonth ? 1 : 0.45)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .contentShape(Rectangle())
                    .background(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.15) : (calendar.isDateInToday(date) ? Color.secondary.opacity(0.10) : Color.clear), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(date.formatted(date: .long, time: .omitted)), \(String(format: String(localized: "calendar.shift.count"), dayShifts.count))")
                .accessibilityIdentifier("calendar.day.\(date.formatted(.iso8601.year().month().day()))")
            }
        }
    }
}

struct YearHeatView: View {
    let year: Date; let shifts: [Shift]; let breaks: [ShiftBreak]
    @Binding var selectedDate: Date
    @Binding var display: CalendarDisplay
    let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(1...12, id: \.self) { month in
                let date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: year), month: month, day: 1))!
                let minutes = shifts.filter { Calendar.current.isDate($0.scheduledStart, equalTo: date, toGranularity: .month) }.reduce(0) { $0 + Int($1.scheduledEnd.timeIntervalSince($1.scheduledStart) / 60) }
                Button { selectedDate = date; display = .month } label: {
                    VStack { Text(date, format: .dateTime.month(.abbreviated)); Text(DurationFormatter.string(minutes: minutes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                        .frame(maxWidth: .infinity, minHeight: 70).background(Color.accentColor.opacity(min(0.55, 0.07 + Double(minutes) / 12_000)), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
    }
}

struct ShiftRow: View {
    @Environment(\.locale) private var locale
    let shift: Shift; let job: Job?; let breaks: [ShiftBreak]
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: job?.colorHex ?? "999999")).frame(width: 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(job?.displayName ?? String(localized: "job.unknown")).font(.headline)
                Text("\(shift.scheduledStart.formatted(date: .omitted, time: .shortened)) – \(shift.scheduledEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline.monospacedDigit())
                if !breaks.isEmpty { Text(String(format: String(localized: "shift.break.minutes"), breaks.reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) })).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Text(shift.status.localizedTitle(locale: locale)).font(.caption).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }.padding(12).background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Shift.scheduledStart) private var allShifts: [Shift]
    @Query private var jobs: [Job]
    @Query private var breaks: [ShiftBreak]
    @Query private var rates: [WageRate]
    @Query private var premiumRules: [PremiumRule]
    let date: Date
    @State private var showingNewShift = false
    @State private var editingShift: Shift?

    private var dayShifts: [Shift] {
        allShifts.filter { !$0.isDeleted && Calendar.current.isDate($0.scheduledStart, inSameDayAs: date) }
    }

    private var totalMinutes: Int {
        dayShifts.filter { $0.status != .cancelled }.reduce(0) { result, shift in
            let breakMinutes = breaks.filter { $0.shiftID == shift.id && !$0.isActual }.reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
            return result + max(0, Int(shift.scheduledEnd.timeIntervalSince(shift.scheduledStart) / 60) - breakMinutes)
        }
    }

    private var estimatedTotal: Decimal {
        dayShifts.filter { $0.status != .cancelled }.reduce(Decimal.zero) { total, shift in
            guard let job = jobs.first(where: { $0.id == shift.jobID }) else { return total }
            let result = try? CalculationEngine.calculate(
                start: shift.scheduledStart,
                end: shift.scheduledEnd,
                breaks: ModelAdapters.breaks(for: shift.id, actual: false, all: breaks),
                hourlyRate: ModelAdapters.wageRate(for: shift.jobID, on: shift.scheduledStart, rates: rates),
                premiums: ModelAdapters.premiumSpecs(for: shift.jobID, on: shift.scheduledStart, rules: premiumRules),
                transport: shift.transportAmount,
                bonus: shift.bonusAmount,
                deduction: shift.deductionAmount,
                roundingInterval: job.roundingIntervalMinutes,
                roundingDirection: job.roundingDirection,
                wageRoundingUnit: job.wageRoundingUnit
            )
            return total + (result?.total ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(date, format: .dateTime.year().month(.wide).day().weekday(.wide)).font(.title2.bold())
                        HStack {
                            LabeledContent("earnings.hours", value: DurationFormatter.string(minutes: totalMinutes))
                            Spacer()
                            Text(CurrencyFormatter.string(estimatedTotal)).font(.headline.monospacedDigit())
                        }
                    }
                    .accessibilityIdentifier("calendar.day.detail")
                }
                Section("calendar.day.shifts") {
                    if dayShifts.isEmpty {
                        ContentUnavailableView("calendar.empty.day", systemImage: "calendar")
                    }
                    ForEach(dayShifts) { shift in
                        Button { editingShift = shift } label: {
                            ShiftRow(shift: shift, job: jobs.first { $0.id == shift.jobID }, breaks: breaks.filter { $0.shiftID == shift.id })
                        }.buttonStyle(.plain)
                    }
                }
                Section {
                    Button { showingNewShift = true } label: {
                        Label("calendar.day.add", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("calendar.day.add")
                }
            }
            .navigationTitle("calendar.day.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.close") { dismiss() } } }
            .sheet(isPresented: $showingNewShift) { ShiftEditorView(initialDate: date) }
            .sheet(item: $editingShift) { ShiftEditorView(shift: $0) }
        }
    }
}
