import LocalAuthentication
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DocumentLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Query(sort: \EmploymentDocument.createdAt, order: .reverse) private var documents: [EmploymentDocument]
    @Query(sort: \Job.createdAt) private var jobs: [Job]
    @Query private var settings: [UserSettings]
    @State private var selectedJobID: UUID?
    @State private var selectedType = EmploymentDocumentType.payslip
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importingFile = false
    @State private var message: String?
    @State private var unlocked = false

    init(initialJobID: UUID? = nil) {
        _selectedJobID = State(initialValue: initialJobID)
    }

    var body: some View {
        Group {
            if settings.first?.biometricLockEnabled == true && !unlocked {
                SensitiveAccessGate { unlocked = true }
            } else {
                content
            }
        }
        .navigationTitle("document.library")
        .onDisappear { unlocked = false }
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.image, .pdf]) { result in
            do {
                let url = try result.get()
                guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
                defer { url.stopAccessingSecurityScopedResource() }
                try addDocument(data: Data(contentsOf: url), originalName: url.lastPathComponent, contentType: UTType(filenameExtension: url.pathExtension) ?? .data)
            } catch { message = error.localizedDescription }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { @MainActor in
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadUnknown) }
                    try addDocument(data: data, originalName: "Photo-\(Date().formatted(.iso8601.year().month().day())).jpg", contentType: .jpeg)
                } catch { message = error.localizedDescription }
                selectedPhoto = nil
            }
        }
        .alert("common.notice", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("common.ok") { message = nil }
        } message: { Text(message ?? "") }
    }

    private var content: some View {
        List {
            Section("document.add") {
                Picker("shift.job", selection: $selectedJobID) {
                    Text("common.choose").tag(nil as UUID?)
                    ForEach(jobs) { Text($0.displayName).tag(Optional($0.id)) }
                }
                Picker("document.type", selection: $selectedType) {
                    ForEach(EmploymentDocumentType.allCases) { type in
                        Text(type.localizedTitle(locale: locale)).tag(type)
                    }
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("document.add.photo", systemImage: "camera")
                }
                .disabled(selectedJobID == nil)
                Button { importingFile = true } label: { Label("document.add.file", systemImage: "doc.badge.plus") }
                    .disabled(selectedJobID == nil)
            }

            Section("document.saved") {
                if documents.isEmpty {
                    ContentUnavailableView("document.empty", systemImage: "doc.text.magnifyingglass", description: Text("document.empty.description"))
                }
                ForEach(documents) { document in
                    NavigationLink {
                        DocumentDetailView(document: document)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.type.localizedTitle(locale: locale))
                            Text(jobName(document.jobID)).font(.caption).foregroundStyle(.secondary)
                            Text(document.originalFileName).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
            }
        }
        .onAppear { if selectedJobID == nil { selectedJobID = jobs.first?.id } }
    }

    private func jobName(_ id: UUID?) -> String {
        jobs.first(where: { $0.id == id })?.displayName ?? String(localized: "job.unknown")
    }

    private func addDocument(data: Data, originalName: String, contentType: UTType) throws {
        guard let selectedJobID else { return }
        let saved = try DocumentFileStore.store(data, preferredExtension: contentType.preferredFilenameExtension ?? URL(fileURLWithPath: originalName).pathExtension)
        context.insert(EmploymentDocument(jobID: selectedJobID, type: selectedType, originalFileName: originalName, localFileName: saved.fileName, contentTypeIdentifier: contentType.identifier, fileSize: saved.size))
        try context.save()
    }
}

private struct DocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    let document: EmploymentDocument
    @State private var recognizedText: String
    @State private var recognizing = false
    @State private var message: String?
    @State private var showingDelete = false

    init(document: EmploymentDocument) {
        self.document = document
        _recognizedText = State(initialValue: document.recognizedText)
    }

    var body: some View {
        Form {
            Section("document.file") {
                LabeledContent("document.name", value: document.originalFileName)
                LabeledContent("document.size", value: ByteCountFormatter.string(fromByteCount: document.fileSize, countStyle: .file))
                if let url = try? DocumentFileStore.url(for: document.localFileName) {
                    ShareLink(item: url) { Label("document.share", systemImage: "square.and.arrow.up") }
                }
                Text("document.share.warning").font(.caption).foregroundStyle(.secondary)
            }
            Section("document.ocr") {
                Button {
                    recognize()
                } label: {
                    if recognizing { ProgressView() } else { Label("document.ocr.start", systemImage: "text.viewfinder") }
                }
                .disabled(recognizing)
                Text("document.ocr.disclaimer").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $recognizedText).frame(minHeight: 180)
                Button("common.save") {
                    document.recognizedText = recognizedText
                    document.updatedAt = Date()
                    try? context.save()
                    message = String(localized: "document.ocr.saved")
                }
            }
            Section {
                Button("document.delete", role: .destructive) { showingDelete = true }
            }
        }
        .navigationTitle(document.type.localizedTitle(locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .alert("common.notice", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("common.ok") { message = nil } } message: { Text(message ?? "") }
        .confirmationDialog("document.delete.confirm", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("document.delete", role: .destructive) {
                try? DocumentFileStore.remove(document.localFileName)
                context.delete(document)
                try? context.save()
                dismiss()
            }
        }
    }

    private func recognize() {
        recognizing = true
        Task { @MainActor in
            defer { recognizing = false }
            do {
                let url = try DocumentFileStore.url(for: document.localFileName)
                recognizedText = try await Task.detached(priority: .userInitiated) {
                    try DeviceOCRService.recognizeText(at: url)
                }.value
                if recognizedText.isEmpty { message = String(localized: "document.ocr.empty") }
            } catch { message = error.localizedDescription }
        }
    }
}

struct SensitiveAccessGate: View {
    let onUnlock: () -> Void
    @State private var message: String?
    @State private var authenticating = false

    var body: some View {
        ContentUnavailableView {
            Label("privacy.locked", systemImage: "lock.shield")
        } description: {
            Text(message ?? String(localized: "privacy.locked.description"))
        } actions: {
            Button("privacy.unlock") { authenticate() }.buttonStyle(.borderedProminent).disabled(authenticating)
        }
    }

    private func authenticate() {
        authenticating = true
        Task { @MainActor in
            defer { authenticating = false }
            do {
                let context = LAContext()
                var error: NSError?
                guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { throw error ?? LAError(.biometryNotAvailable) }
                if try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "privacy.unlock.reason")) { onUnlock() }
            } catch { message = error.localizedDescription }
        }
    }
}
