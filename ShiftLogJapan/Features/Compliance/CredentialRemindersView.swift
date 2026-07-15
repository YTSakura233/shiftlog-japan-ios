import SwiftData
import SwiftUI

struct CredentialRemindersView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Query(sort: \CredentialReminder.dueDate) private var reminders: [CredentialReminder]
    @State private var editing: CredentialReminder?
    @State private var showingNew = false

    var body: some View {
        List {
            if reminders.isEmpty {
                ContentUnavailableView("credential.empty", systemImage: "calendar.badge.exclamationmark", description: Text("credential.empty.description"))
            }
            ForEach(reminders) { reminder in
                Button { editing = reminder } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.type.localizedTitle(locale: locale))
                            Text(reminder.dueDate, format: .dateTime.year().month().day()).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !reminder.enabled { Image(systemName: "bell.slash").foregroundStyle(.secondary) }
                        dueBadge(reminder.dueDate)
                    }
                }.buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets {
                    let reminder = reminders[index]
                    Task { await NotificationService.shared.cancelCredentialReminders(reminderID: reminder.id) }
                    context.delete(reminder)
                }
                try? context.save()
            }
        }
        .navigationTitle("credential.title")
        .toolbar { Button { showingNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("credential.add") }
        .sheet(isPresented: $showingNew) { CredentialReminderEditor() }
        .sheet(item: $editing) { CredentialReminderEditor(reminder: $0) }
    }

    @ViewBuilder private func dueBadge(_ date: Date) -> some View {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { Text("credential.expired").font(.caption.bold()).foregroundStyle(.red) }
        else if days <= 30 { Text(String(format: String(localized: "credential.daysLeft"), days)).font(.caption.bold()).foregroundStyle(.orange) }
    }
}

private struct CredentialReminderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    let reminder: CredentialReminder?
    @State private var type: CredentialReminderType
    @State private var dueDate: Date
    @State private var reminderDays: Set<Int>
    @State private var notes: String
    @State private var enabled: Bool

    init(reminder: CredentialReminder? = nil) {
        self.reminder = reminder
        _type = State(initialValue: reminder?.type ?? .residencePeriod)
        _dueDate = State(initialValue: reminder?.dueDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())!)
        _reminderDays = State(initialValue: Set(reminder?.reminderDays ?? [90, 60, 30, 14, 7]))
        _notes = State(initialValue: reminder?.notes ?? "")
        _enabled = State(initialValue: reminder?.enabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("credential.type", selection: $type) {
                    ForEach(CredentialReminderType.allCases) { type in Text(type.localizedTitle(locale: locale)).tag(type) }
                }
                DatePicker("credential.date", selection: $dueDate, displayedComponents: .date)
                Toggle("credential.enabled", isOn: $enabled)
                Section("credential.remindBefore") {
                    ForEach([90, 60, 30, 14, 7], id: \.self) { days in
                        Toggle(String(format: String(localized: "credential.daysBefore"), days), isOn: Binding(
                            get: { reminderDays.contains(days) },
                            set: { selected in if selected { reminderDays.insert(days) } else { reminderDays.remove(days) } }
                        ))
                    }
                }
                Section("shift.notes") { TextField("shift.notes.placeholder", text: $notes, axis: .vertical) }
                Text("credential.privacy").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(reminder == nil ? "credential.add" : "credential.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("common.save") { save() } }
            }
        }
    }

    private func save() {
        let target = reminder ?? CredentialReminder(type: type, dueDate: dueDate)
        if reminder == nil { context.insert(target) }
        target.type = type
        target.dueDate = dueDate
        target.reminderDays = Array(reminderDays)
        target.notes = notes
        target.enabled = enabled
        target.updatedAt = Date()
        try? context.save()
        Task {
            await NotificationService.shared.scheduleCredentialReminders(
                reminderID: target.id,
                dueDate: target.dueDate,
                daysBefore: target.reminderDays,
                title: target.type.localizedTitle(locale: locale),
                enabled: target.enabled
            )
        }
        dismiss()
    }
}
