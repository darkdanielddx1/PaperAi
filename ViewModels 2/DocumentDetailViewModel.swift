//
//  DocumentDetailViewModel.swift
//  PaperAI
//
//  Kart çalışma ekranının sunum mantığı: kartları yükler, Tinder-tarzı
//  kaydırma sonuçlarını (Öğrendim / Tekrar Et) backend'e yansıtır.
//

import Foundation
import Observation

/// Bir kaydırma (swipe) hareketinin yönü.
enum SwipeDirection {
    case mastered   // sağa: "Öğrendim"
    case review     // sola: "Tekrar Et"
}

/// Doküman detay / kart çalışma ekranının ViewModel'i.
@MainActor
@Observable
final class DocumentDetailViewModel {

    // MARK: - Bağımlılıklar

    private let database: DatabaseServiceProtocol
    let document: DocumentModel

    // MARK: - Durum

    private(set) var flashcards: [FlashcardModel] = []
    private(set) var isLoading = false

    /// Yapay zekânın kart ürettiğini simüle eden geçici durum (boş dokümanlar).
    private(set) var isGenerating = false

    var errorMessage: String?

    /// O an en üstte gösterilen kartın indeksi.
    private(set) var currentIndex = 0

    // MARK: - Kurulum

    init(document: DocumentModel, database: DatabaseServiceProtocol = MockDatabaseService()) {
        self.document = document
        self.database = database
    }

    // MARK: - Hesaplanmış Durum

    /// Tüm kartlar gözden geçirildi mi?
    var isFinished: Bool { !flashcards.isEmpty && currentIndex >= flashcards.count }

    /// Yüklendi ama hiç kart yok (henüz üretilmemiş).
    var hasNoFlashcards: Bool { !isLoading && !isGenerating && flashcards.isEmpty }

    /// Tamamlanan kart sayısı (progress bar için).
    var completedCount: Int { min(currentIndex, flashcards.count) }

    var totalCount: Int { flashcards.count }

    /// 0...1 aralığında ilerleme oranı.
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    /// Öğrenilen kart sayısı.
    var masteredCount: Int { flashcards.filter(\.isMastered).count }

    // MARK: - Aksiyonlar

    /// Dokümana ait kartları yükler. Kart yoksa kısa bir "üretiliyor"
    /// simülasyonu gösterir (gerçek AI entegrasyonu sonraki adımda).
    func loadFlashcards() async {
        isLoading = true
        errorMessage = nil
        do {
            let cards = try await database.fetchFlashcards(for: document.id)
            isLoading = false

            if cards.isEmpty {
                await simulateGeneration()
            } else {
                flashcards = cards
                currentIndex = 0
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    /// Üstteki kart için kaydırma sonucunu işler ve bir sonraki karta geçer.
    /// - Parameter direction: Kaydırma yönü.
    func handleSwipe(_ direction: SwipeDirection) async {
        guard currentIndex < flashcards.count else { return }
        let card = flashcards[currentIndex]
        let mastered = (direction == .mastered)

        // Yerel state'i hemen güncelle (akıcı animasyon), sonra kalıcılaştır.
        flashcards[currentIndex].isMastered = mastered
        flashcards[currentIndex].lastReviewed = Date()
        currentIndex += 1

        do {
            try await database.setFlashcardMastery(flashcardId: card.id, isMastered: mastered)
            // Widget'ı güncel öğrenilmemiş kartlarla tazele.
            WidgetDataManager.shared.saveCardsForWidget(flashcards)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deste bittiğinde baştan başlatır.
    func restart() {
        currentIndex = 0
    }

    // MARK: - Yardımcılar

    private func simulateGeneration() async {
        isGenerating = true
        // AI kart üretimini taklit eden kısa bekleme.
        try? await Task.sleep(for: .seconds(2))
        isGenerating = false
    }
}
