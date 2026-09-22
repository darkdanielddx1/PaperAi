//
//  DashboardViewModel.swift
//  PaperAI
//
//  Ana ekranın (doküman listesi) sunum mantığı.
//  Modern @Observable makrosu + Swift Concurrency kullanır.
//

import Foundation
import Observation

/// Dashboard ekranının durumunu ve iş mantığını yöneten ViewModel.
///
/// - Note: `@MainActor` ile işaretlidir; tüm state güncellemeleri ana thread'de
///   yapılır, böylece UI güvenle güncellenir. Bağımlılık (`DatabaseServiceProtocol`)
///   dışarıdan enjekte edilir → gerçek backend'e geçiş tek satırlıktır.
@MainActor
@Observable
final class DashboardViewModel {

    // MARK: - Bağımlılıklar

    private let database: DatabaseServiceProtocol
    private let aiService: AIServiceProtocol

    /// Oturum açmış kullanıcı. Gerçek uygulamada Auth katmanından gelir.
    let currentUser: UserModel

    // MARK: - Yayınlanan Durum (State)

    /// Ekranda listelenen dokümanlar (yeniden eskiye sıralı).
    private(set) var documents: [DocumentModel] = []

    /// İlk yükleme sırasında spinner göstermek için.
    private(set) var isLoading = false

    /// Kullanıcıya gösterilecek hata mesajı (varsa).
    var errorMessage: String?

    // MARK: - Kurulum

    // Sadece bu init bloğunu yapıştır:
        init(
            database: DatabaseServiceProtocol = MockDatabaseService(),
            aiService: AIServiceProtocol? = nil,
            currentUser: UserModel = .preview
        ) {
            self.database = database
            // Eğer dışarıdan bir servis verilmediyse, direkt bizim canavar Groq (OpenAIService) başlasın
            self.aiService = aiService ?? OpenAIService()
            self.currentUser = currentUser
        }

    // MARK: - Hesaplanmış Durum

    /// Yükleme bittiğinde hiç doküman yoksa boş durum gösterilir.
    var isEmpty: Bool { !isLoading && documents.isEmpty }

    // MARK: - Aksiyonlar

    /// Kullanıcının tüm dokümanlarını yükler.
    func loadDocuments() async {
        isLoading = true
        errorMessage = nil
        do {
            documents = try await database.fetchDocuments(for: currentUser.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Bir dokümanı siler ve listeyi günceller (iyimser/optimistic güncelleme).
    /// - Parameter document: Silinecek doküman.
    func deleteDocument(_ document: DocumentModel) async {
        // Önce UI'dan kaldır, hata olursa geri ekle → akıcı deneyim.
        let backup = documents
        documents.removeAll { $0.id == document.id }
        do {
            try await database.deleteDocument(id: document.id)
        } catch {
            documents = backup
            errorMessage = error.localizedDescription
        }
    }

    /// `IndexSet` ile silme (List.onDelete köprüsü).
    func deleteDocuments(at offsets: IndexSet) async {
        let targets = offsets.map { documents[$0] }
        for document in targets {
            await deleteDocument(document)
        }
    }

    /// Deep link çözümlemesi için: verilen kimliğe sahip dokümanı bulur.
    /// Liste henüz yüklenmemişse önce yükler.
    /// - Parameter id: Aranan dokümanın kimliği.
    /// - Returns: Bulunursa doküman, aksi halde `nil`.
    func document(withId id: UUID) async -> DocumentModel? {
        if documents.isEmpty {
            await loadDocuments()
        }
        return documents.first { $0.id == id }
    }

    /// Detay ekranı için, aynı veritabanı örneğini paylaşan bir ViewModel üretir.
    /// (Mock servis bir `actor` olduğundan tek örnek paylaşmak veri tutarlılığını sağlar.)
    func makeDetailViewModel(for document: DocumentModel) -> DocumentDetailViewModel {
        DocumentDetailViewModel(document: document, database: database)
    }

    /// Taranmış/yüklenmiş ham metinden yeni bir doküman oluşturur, AI ile
    /// bilgi kartları üretir ve hepsini kalıcılaştırır.
    ///
    /// UploadSheetView bu metodu çağırır; üretim/hata durumunu göstermesi için
    /// hata `throws` ile dışarı verilir.
    /// - Parameters:
    ///   - title: Doküman başlığı (dosya adı veya tarih).
    ///   - rawText: OCR/PDF'ten çıkarılmış ham metin.
    /// - Returns: Oluşturulan doküman (kart kimlikleriyle birlikte).
    @discardableResult
    func importDocument(title: String, rawText: String) async throws -> DocumentModel {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw AIServiceError.emptyDocument }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Dokümanı oluştur.
        var document = DocumentModel(
            userId: currentUser.id,
            title: cleanTitle.isEmpty ? "Adsız Doküman" : cleanTitle,
            rawText: trimmedText,
            createdAt: Date()
        )
        let created = try await database.createDocument(document)
        document = created

        // 2) AI ile kartları üret.
        let cards = try await aiService.generateFlashcards(
            from: trimmedText,
            documentId: created.id
        )

        // 3) Kartları kalıcılaştır ve dokümanın kart listesini güncelle.
        try await database.addFlashcards(cards, to: created.id)
        document.flashcardIds = cards.map(\.id)

        // 4) Listeyi güncelle (en üste ekle).
        documents.insert(document, at: 0)

        // 5) Yeni üretilen kartları widget'a yansıt.
        WidgetDataManager.shared.saveCardsForWidget(cards)

        return document
    }
}
