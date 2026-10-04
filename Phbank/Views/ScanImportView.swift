//
//  ScanImportView.swift
//  Phbank
//
//  Receipt scan (camera), receipt photo (library) and bank-statement PDF import.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

struct ScanImportView: View {
    @Environment(\.dismiss) private var dismiss

    let importer: ImportController
    let fallbackDate: Date

    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var photoItem: PhotosPickerItem?
    @State private var issue = AIReadiness.issue()
    @State private var message: String?

    private let cameraAvailable = VNDocumentCameraViewController.isSupported

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let issue { AISetupBanner(issue: issue) }

                Button { showScanner = true } label: {
                    ScanActionCard(
                        title: "Scan receipt",
                        subtitle: cameraAvailable ? "Capture with the camera" : "Camera scanning isn't available here",
                        icon: "camera.viewfinder"
                    )
                }
                .disabled(!cameraAvailable || issue != nil)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    ScanActionCard(title: "Choose receipt photo", subtitle: "From your photo library", icon: "photo")
                }
                .disabled(issue != nil)

                Button { showFileImporter = true } label: {
                    ScanActionCard(title: "Import PDF", subtitle: "Bank statement from Files", icon: "doc.badge.plus")
                }
                .disabled(issue != nil)

                if let message {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }

                Text("The file is sent to Google Gemini to read the entries. You review everything before it is saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(24)
            .buttonStyle(.plain)
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
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url):
                    let importer = importer
                    let date = fallbackDate
                    dismiss()
                    Task { await importer.processPDF(url: url, fallbackDate: date) }
                case .failure:
                    message = "The PDF could not be opened."
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
                        message = "The photo could not be loaded."
                    }
                }
            }
        }
        .tint(JournalTheme.gold)
    }

    private func begin(_ image: UIImage) {
        let importer = importer
        let date = fallbackDate
        dismiss()
        Task { await importer.processImage(image, fallbackDate: date) }
    }
}

struct ScanActionCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .frame(width: 50, height: 50)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(JournalTheme.brown)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
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
