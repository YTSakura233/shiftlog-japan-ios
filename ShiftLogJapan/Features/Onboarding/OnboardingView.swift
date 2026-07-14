import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    let existingSettings: UserSettings?
    @State private var step = 0
    @State private var localeCode: String
    @State private var purpose = "student"
    @State private var limitEnabled = true
    @State private var weeklyHours = 28
    @State private var rollingCheck = true
    @State private var jobName = ""
    @State private var hourlyText = "1,200"
    @State private var issues: [FormIssue] = []
    @FocusState private var wageFieldFocused: Bool

    init(existingSettings: UserSettings?) {
        self.existingSettings = existingSettings
        _localeCode = State(initialValue: existingSettings?.localeCode ?? Self.preferredLocaleCode())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProgressView(value: Double(step + 1), total: 4).padding(.horizontal)
                Group {
                    switch step {
                    case 0: languageStep
                    case 1: purposeStep
                    case 2: ruleStep
                    default: firstJobStep
                    }
                }
                Spacer()
                Button(step == 3 ? "onboarding.finish" : "common.continue") {
                    if step < 3 { step += 1 } else { finish() }
                }
                .accessibilityIdentifier("onboarding.continue")
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding(24).navigationTitle("app.name").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done") { wageFieldFocused = false; formatWageIfValid() }
                }
            }
        }
        .environment(\.locale, selectedLocale)
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "globe.asia.australia.fill").font(.system(size: 56)).foregroundStyle(.tint)
            Text("onboarding.language.title").font(.largeTitle.bold())
                .accessibilityIdentifier("onboarding.language.title")
            Picker("onboarding.language.title", selection: $localeCode) {
                Text("简体中文").tag("zh-Hans"); Text("日本語").tag("ja"); Text("English").tag("en")
            }.pickerStyle(.segmented)
            Text("onboarding.language.note").foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purposeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "person.text.rectangle").font(.system(size: 52)).foregroundStyle(.tint)
            Text("onboarding.purpose.title").font(.largeTitle.bold())
                .accessibilityIdentifier("onboarding.purpose.title")
            Picker("onboarding.purpose.title", selection: $purpose) {
                Text("purpose.student").tag("student")
                Text("purpose.family").tag("family")
                Text("purpose.general").tag("general")
                Text("purpose.custom").tag("custom")
            }.pickerStyle(.inline)
            Label("disclaimer.short", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: purpose) { _, value in limitEnabled = value == "student" || value == "family" }
    }

    private var ruleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 52)).foregroundStyle(.orange)
            Text("onboarding.rule.title").font(.largeTitle.bold())
            Toggle("settings.limit.enabled", isOn: $limitEnabled)
            if limitEnabled {
                Stepper(value: $weeklyHours, in: 1...80) { LabeledContent("settings.weekly.limit", value: "\(weeklyHours) h") }
                Toggle("settings.rolling", isOn: $rollingCheck)
            }
            Text("disclaimer.full").font(.footnote).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var firstJobStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !issues.isEmpty { FormErrorSummary(issues: issues) }
            Image(systemName: "briefcase.fill").font(.system(size: 52)).foregroundStyle(.teal)
            Text("onboarding.job.title").font(.largeTitle.bold())
            TextField("job.name", text: $jobName)
                .accessibilityIdentifier("onboarding.job.name")
                .textFieldStyle(.roundedBorder)
                .onChange(of: jobName) { _, _ in clearResolvedIssues() }
            if let issue = issues.first(where: { $0.fieldID == "job.field.name" }) { InlineFieldError(message: issue.message) }
            HStack {
                TextField("job.hourly.placeholder", text: $hourlyText)
                    .keyboardType(.numberPad)
                    .focused($wageFieldFocused)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: hourlyText) { _, _ in clearResolvedIssues() }
                Text("job.hourly.unit").foregroundStyle(.secondary)
            }
            if let issue = issues.first(where: { $0.fieldID == "job.field.wage" }) { InlineFieldError(message: issue.message) }
            Text("onboarding.job.note").font(.footnote).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func finish() {
        var problems: [FormIssue] = []
        if jobName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append(FormIssue("job.name.required", message: String(localized: "error.job.name.required", locale: selectedLocale), fieldID: "job.field.name"))
        }
        let hourlyAmount: Decimal
        do { hourlyAmount = try WageInputParser.parseJPY(hourlyText) }
        catch {
            let message: String = switch error as? WageInputError {
            case .empty: String(localized: "error.job.wage.required", locale: selectedLocale)
            case .nonPositive: String(localized: "error.job.wage.positive", locale: selectedLocale)
            default: String(localized: "error.job.wage.invalid", locale: selectedLocale)
            }
            problems.append(FormIssue("job.wage.invalid", message: message, fieldID: "job.field.wage"))
            hourlyAmount = 0
        }
        guard problems.isEmpty else { issues = problems; return }
        let settings = existingSettings ?? UserSettings()
        settings.localeCode = localeCode
        settings.workLimitEnabled = limitEnabled
        settings.weeklyLimitMinutes = weeklyHours * 60
        settings.cautionMinutes = min(24 * 60, settings.weeklyLimitMinutes)
        settings.warningMinutes = min(26 * 60, settings.weeklyLimitMinutes)
        settings.rollingSevenDayCheckEnabled = rollingCheck
        settings.disclaimerAcceptedAt = Date()
        settings.onboardingCompleted = true
        settings.updatedAt = Date()
        if existingSettings == nil { context.insert(settings) }
        let job = Job(displayName: jobName, hourlyAmount: hourlyAmount, colorHex: AppTheme.palette[0])
        context.insert(job)
        context.insert(WageRate(jobID: job.id, hourlyAmount: hourlyAmount))
        try? context.save()
    }

    private func clearResolvedIssues() {
        issues.removeAll { issue in
            switch issue.id {
            case "job.name.required": !jobName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case "job.wage.invalid": (try? WageInputParser.parseJPY(hourlyText)) != nil
            default: false
            }
        }
    }

    private func formatWageIfValid() {
        guard let amount = try? WageInputParser.parseJPY(hourlyText) else { return }
        hourlyText = WageInputParser.formatJPY(amount, locale: selectedLocale)
    }

    private var selectedLocale: Locale { Locale(identifier: localeCode) }

    private static func preferredLocaleCode(_ locale: Locale = .current) -> String {
        let identifier = locale.identifier.lowercased()
        if identifier.hasPrefix("ja") { return "ja" }
        if identifier.hasPrefix("en") { return "en" }
        return "zh-Hans"
    }
}
