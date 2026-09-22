//
//  UploadSheetView.swift
//  PaperAI
//
//  "+" butonuyla açılan modal: Kamera ile tara veya PDF/dosya yükle.
//  Metin çıkarıldıktan sonra AIService ile kartlar üretilip veritabanına
//  kaydedilir; süreç boyunca şık bir yüklenme animasyonu gösterilir.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct UploadSheetView: View {

    /// Dashboard ile aynı VM; içe aktarma (importDocument) bunun üzerinden yapılır.
    let viewModel: DashboardViewModel

    @Environment(\.dismiss) private var dismiss

    /// Ekranın o anki aşaması.
    private enum Phase: Equatable {
        case options          // seçim menüsü
        case extracting       // OCR / PDF metin çıkarma
        case generating       // AI kart üretimi
        case failed(String)   // hata
    }

    @State private var phase: Phase = .options
    @State private var showScanner = false
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .options:
                    optionsView
                case .extracting:
                    progressView(
                        title: "Metin çıkarılıyor…",
                        subtitle: "Dokümanındaki yazılar okunuyor.",
                        systemImage: "text.viewfinder"
                    )
                case .generating:
                    progressView(
                        title: "Yapay zekâ kartları üretiyor…",
                        subtitle: "En kritik bilgiler soru-cevap kartlarına dönüştürülüyor.",
                        systemImage: "sparkles"
                    )
                case .failed(let message):
                    failedView(message: message)
                }
            }
            .padding()
            .navigationTitle("Doküman Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if phase == .options {
                        Button("Kapat") { dismiss() }
                    }
                }
            }
            // Kamera tarayıcı tam ekran açılır.
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView(
                    onComplete: { text in
                        showScanner = false
                        handleExtractedText(text, defaultTitle: scanTitle())
                    },
                    onError: { error in
                        showScanner = false
                        phase = .failed(error.localizedDescription)
                    },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
            // PDF / dosya seçici.
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
        .interactiveDismissDisabled(phase == .extracting || phase == .generating)
    }

    // MARK: - Seçim Menüsü

    private var optionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            optionCard(
                title: "Kamera ile Tara",
                subtitle: "Ders notunu veya kitabı tarat.",
                systemImage: "camera.viewfinder",
                gradient: [.blue, .indigo]
            ) {
                showScanner = true
            }

            optionCard(
                title: "PDF / Dosya Yükle",
                subtitle: "Cihazından bir PDF dosyası seç.",
                systemImage: "doc.badge.arrow.up",
                gradient: [.teal, .green]
            ) {
                showFileImporter = true
            }

            Spacer()
        }
    }

    private func optionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        gradient: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - İlerleme Görünümü

    private func progressView(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 54))
                .foregroundStyle(.purple)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .controlSize(.large)

            Spacer()
        }
    }

    // MARK: - Hata Görünümü

    private func failedView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("İşlem tamamlanamadı")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                phase = .options
            } label: {
                Text("Tekrar Dene")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Spacer()
        }
    }

    // MARK: - Akış Mantığı

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            phase = .extracting
            Task {
                let title = url.deletingPathExtension().lastPathComponent
                let text = extractTextFromPDF(at: url)
                await MainActor.run {
                    handleExtractedText(text, defaultTitle: title)
                }
            }
        case .failure(let error):
            phase = .failed(error.localizedDescription)
        }
    }

    /// Metin çıkarıldıktan sonra AI üretimini başlatır.
    private func handleExtractedText(_ text: String, defaultTitle: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .failed("Dokümandan okunabilir metin çıkarılamadı. Daha net bir tarama/dosya deneyin.")
            return
        }
        phase = .generating
        Task {
            do {
                try await viewModel.importDocument(title: defaultTitle, rawText: trimmed)
                dismiss()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// PDF dosyasından metni PDFKit ile çıkarır (security-scoped erişim ile).
    private func extractTextFromPDF(at url: URL) -> String {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { return "" }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let pageText = document.page(at: index)?.string, !pageText.isEmpty {
                pages.append(pageText)
            }
        }
        return pages.joined(separator: "\n\n")
    }

    private func scanTitle() -> String {
        "Tarama · " + Date.now.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    UploadSheetView(viewModel: DashboardViewModel())
}
