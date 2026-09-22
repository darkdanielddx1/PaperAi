//
//  DocumentScannerView.swift
//  PaperAI
//
//  Apple VisionKit (VNDocumentCameraViewController) ile döküman tarama +
//  Vision (VNRecognizeTextRequest) ile OCR. Taranan tüm sayfaların metnini
//  tek bir String olarak geri döndürür.
//
//  Info.plist gereksinimi: NSCameraUsageDescription
//

import SwiftUI
import VisionKit
import Vision

/// Kamerayı bir döküman tarayıcı olarak açan SwiftUI sarmalayıcısı.
///
/// Kullanıcı "Save" dediğinde taranan sayfalar OCR'dan geçirilir ve
/// `onComplete` ile birleşik metin döndürülür.
struct DocumentScannerView: UIViewControllerRepresentable {

    /// OCR tamamlandığında birleşik metni döndürür.
    let onComplete: (String) -> Void
    /// Tarama veya OCR sırasında hata olursa çağrılır.
    let onError: (Error) -> Void
    /// Kullanıcı iptal ederse çağrılır.
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // Güncelleme gerekmez; tek seferlik akış.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator (Delegate + OCR)

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {

        private let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Sayfa görüntülerini ana thread'i bloklamadan OCR'a ver.
            let images: [CGImage] = (0..<scan.pageCount).compactMap {
                scan.imageOfPage(at: $0).cgImage
            }
            let onComplete = parent.onComplete
            let onError = parent.onError

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let text = try Coordinator.recognizeText(from: images)
                    DispatchQueue.main.async { onComplete(text) }
                } catch {
                    DispatchQueue.main.async { onError(error) }
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onError(error)
        }

        // MARK: OCR

        /// Verilen görüntülerden yüksek doğruluklu metin ayıklar.
        static func recognizeText(from images: [CGImage]) throws -> String {
            var pageTexts: [String] = []

            for cgImage in images {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["tr-TR", "en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])

                let observations = request.results ?? []
                let pageText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                if !pageText.isEmpty {
                    pageTexts.append(pageText)
                }
            }

            return pageTexts.joined(separator: "\n\n")
        }
    }
}
