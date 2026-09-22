//
//  DocumentModel.swift
//  PaperAI
//
//  Kullanıcının taradığı/yüklediği bir belgeyi temsil eden veri modeli.
//

import Foundation

/// Taranan bir doküman veya PDF'ten çıkarılan ham metni temsil eder.
///
/// Her doküman bir kullanıcıya aittir (`userId`) ve kendisinden üretilmiş
/// bilgi kartlarının kimliklerini (`flashcardIds`) tutar.
struct DocumentModel: Codable, Identifiable, Hashable {

    /// Dokümanın benzersiz kimliği.
    let id: UUID

    /// Dokümanı oluşturan kullanıcının Auth kimliği.
    let userId: String

    /// Kullanıcıya gösterilen doküman başlığı.
    var title: String

    /// Taranan veya PDF'ten çıkarılan ham metin (OCR / PDF text).
    var rawText: String

    /// Dokümanın oluşturulma tarihi.
    var createdAt: Date

    /// Bu dokümandan üretilmiş bilgi kartlarının kimlikleri.
    var flashcardIds: [UUID]

    init(
        id: UUID = UUID(),
        userId: String,
        title: String,
        rawText: String,
        createdAt: Date = Date(),
        flashcardIds: [UUID] = []
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.rawText = rawText
        self.createdAt = createdAt
        self.flashcardIds = flashcardIds
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case rawText = "raw_text"
        case createdAt = "created_at"
        case flashcardIds = "flashcard_ids"
    }
}

// MARK: - Yardımcı Hesaplanmış Alanlar

extension DocumentModel {
    /// Bu dokümana bağlı bilgi kartı sayısı.
    var flashcardCount: Int { flashcardIds.count }

    /// Ham metnin listelerde göstermek için kısaltılmış hâli.
    var previewText: String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 140 else { return trimmed }
        return String(trimmed.prefix(140)) + "…"
    }
}

// MARK: - Örnek Veri

extension DocumentModel {
    static let preview = DocumentModel(
        userId: UserModel.preview.id,
        title: "Fransız İhtilali — Ders Notu",
        rawText: "1789 yılında başlayan Fransız İhtilali, Avrupa tarihinin dönüm noktalarından biridir…",
        createdAt: Date(timeIntervalSince1970: 1_710_500_000),
        flashcardIds: []
    )
}
