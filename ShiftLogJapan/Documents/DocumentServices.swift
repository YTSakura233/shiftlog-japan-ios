import Foundation
import PDFKit
import UniformTypeIdentifiers
import Vision

enum DocumentFileError: LocalizedError {
    case tooLarge
    var errorDescription: String? { String(localized: "document.error.tooLarge") }
}

enum DocumentFileStore {
    static let maximumFileSize = 25 * 1_024 * 1_024

    static func directoryURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("EmploymentDocuments", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        return directory
    }

    static func store(_ data: Data, preferredExtension: String, fileManager: FileManager = .default) throws -> (fileName: String, size: Int64) {
        guard data.count <= maximumFileSize else { throw DocumentFileError.tooLarge }
        let cleanExtension = preferredExtension.lowercased().filter { $0.isLetter || $0.isNumber }
        let fileName = UUID().uuidString + (cleanExtension.isEmpty ? "" : ".\(cleanExtension)")
        let url = try directoryURL(fileManager: fileManager).appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return (fileName, Int64(data.count))
    }

    static func url(for fileName: String, fileManager: FileManager = .default) throws -> URL {
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        guard safeName == fileName, !safeName.isEmpty else { throw CocoaError(.fileReadInvalidFileName) }
        return try directoryURL(fileManager: fileManager).appendingPathComponent(safeName)
    }

    static func remove(_ fileName: String, fileManager: FileManager = .default) throws {
        let fileURL = try url(for: fileName, fileManager: fileManager)
        if fileManager.fileExists(atPath: fileURL.path) { try fileManager.removeItem(at: fileURL) }
    }
}

enum DeviceOCRService {
    static func recognizeText(at url: URL) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ja-JP", "zh-Hans", "en-US"]

        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url), let page = document.page(at: 0) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let image = page.thumbnail(of: CGSize(width: 2_000, height: 2_000), for: .mediaBox)
            guard let cgImage = image.cgImage else { throw CocoaError(.fileReadCorruptFile) }
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } else {
            try VNImageRequestHandler(url: url, options: [:]).perform([request])
        }

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
