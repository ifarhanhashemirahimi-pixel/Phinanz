//
//  ScanImportView.swift
//  Phinanz
//
//  Receipt scan (camera), receipt photo (library) and bank-statement PDF import
//  with AI, plus bank CSV import that runs entirely on the device.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

struct ScanImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var history: [Expense]

    let importer: ImportController
    let fallbackDate: Date

    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var fileKind: FileKind = .pdf
    @State private var photoItem: PhotosPickerItem?
    @State private var issue = AIReadiness.issue()
    @State private var message: String?

    private let cameraAvailable = VNDocumentCameraViewController.isSupported

    var body: some View {
        NavigationStack {
            List {
                if let issue {
                    Section {
                        AISetupBanner(issue: issue)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    Button { showScanner = true } label: {
                        ImportOptionRow(
                            title: "Scan Receipt",
                            subtitle: cameraAvailable ? "Capture with the camera" : "Camera scanning isn't available here",
                            systemName: "doc.viewfinder",
                            color: .blue
                        )
                    }
                    .disabled(!cameraAvailable || issue != nil)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ImportOptionRow(title: "Choose Receipt Photo", subtitle: "From your photo library", systemName: "photo.on.rectangle", color: .orange)
                    }
                    .disabled(issue != nil)

                    Button { pickFile(.pdf) } label: {
                        ImportOptionRow(title: "Import Bank Statement", subtitle: "PDF from the Files app", systemName: "doc.text.fill", color: .indigo)
                    }
                    .disabled(issue != nil)
                } header: {
                    Text("With AI")
                } footer: {
                    Text("The file is sent to Google Gemini to read the entries. You review everything before it is saved.")
                }

                Section {
                    Button { pickFile(.csv) } label: {
                        ImportOptionRow(title: "Import Bank CSV", subtitle: "Export from your bank's website or app", systemName: "building.columns.fill", color: .green)
                    }
                    .accessibilityIdentifier("import-bank-csv")
                } header: {
                    Text("On This iPhone")
                } footer: {
                    Text("Works with Sparkasse, ING, DKB, N26, Commerzbank, comdirect, Volksbank, Postbank and most other banks. The file never leaves your device.")
                }

                if let message {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { issue = AIReadiness.issue() }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScanner { image in
                    showScanner = false
                    guard let image else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(450)) // let the cover finish dismissing
                        begin(image)
                    }
                }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: fileKind.types) { result in
                switch (result, fileKind) {
                case (.success(let url), .pdf):
                    let importer = importer
                    let date = fallbackDate
                    dismiss()
                    Task { await importer.processPDF(url: url, fallbackDate: date) }
                case (.success(let url), .csv):
                    let importer = importer
                    let history = history
                    dismiss()
                    Task {
                        try? await Task.sleep(for: .milliseconds(450)) // let this sheet close before the review opens
                        importer.processBankCSV(url: url, history: history)
                    }
                case (.failure, _):
                    message = String(localized: "The file could not be opened.")
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    defer { photoItem = nil }
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        begin(image)
                    } else {
                        message = String(localized: "The photo could not be loaded.")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private enum FileKind {
        case pdf, csv

        var types: [UTType] {
            switch self {
            case .pdf: [.pdf]
            case .csv: [.commaSeparatedText, .tabSeparatedText, .text]
            }
        }
    }

    private func pickFile(_ kind: FileKind) {
        fileKind = kind
        showFileImporter = true
    }

    private func begin(_ image: UIImage) {
        let importer = importer
        let date = fallbackDate
        dismiss()
        Task { await importer.processImage(image, fallbackDate: date) }
    }
}

struct ImportOptionRow: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemName: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: systemName, color: color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(isEnabled ? 1 : 0.4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct DocumentScanner: UIViewControllerRepresentable {
    var onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil) // receipts: first page
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish(nil)
        }
    }
}
