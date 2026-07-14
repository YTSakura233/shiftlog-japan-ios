import SwiftUI

struct FormIssue: Identifiable, Equatable, Sendable {
    let id: String
    let message: String
    let fieldID: String?

    init(_ id: String, message: String, fieldID: String? = nil) {
        self.id = id
        self.message = message
        self.fieldID = fieldID
    }
}

struct FormErrorSummary: View {
    let issues: [FormIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("form.errors.title", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            ForEach(issues) { issue in
                Text("• \(issue.message)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.red)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "form.errors.accessibility"))
        .accessibilityValue(issues.map(\.message).joined(separator: ". "))
        .accessibilityIdentifier("form.error.summary")
    }
}

struct InlineFieldError: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .accessibilityIdentifier("form.error.inline")
    }
}
