//
//  FlashcardModel.swift
//  PaperAI
//
//  Bilgi kartı (flashcard) veri modeli.
//  WidgetKit ile uyumlu olması için tamamen Codable & Sendable'dır;
//  App Group üzerinden paylaşılan container'a yazılıp widget'ta okunabilir.
//

import Foundation

/// Bir bilgi kartını (soru/cevap) temsil eder.
///
/// Hem çalışma (flip) modunda hem de quiz modunda kullanılabilir.
/// Quiz modu için `wrongAnswers` içinde 3 çeldirici seçenek tutulabilir.
///
/// - Note: WidgetKit uyumluluğu için `Sendable` ve `Codable`'dır; ek olarak
///   `TimelineEntry` üretiminde kolaylık sağlaması adına `Hashable`'dır.
struct FlashcardModel: Codable, Identifiable, Hashable, Sendable {

    /// Kartın benzersiz kimliği.
    let id: UUID

    /// Kartın ait olduğu dokümanın kimliği.
    let documentId: UUID

    /// Kartın ön yüzü (soru / kavram).
    var question: String

    /// Kartın arka yüzü (cevap / doğru seçenek).
    var answer: String

    /// Quiz modunda kullanılacak 3 yanlış seçenek (opsiyonel).
    var wrongAnswers: [String]?

    /// Kullanıcının bu kartı öğrenip öğrenmediği.
    var isMastered: Bool

    /// Kartın en son gözden geçirildiği tarih (spaced repetition için).
    var lastReviewed: Date?

    init(
        id: UUID = UUID(),
        documentId: UUID,
        question: String,
        answer: String,
        wrongAnswers: [String]? = nil,
        isMastered: Bool = false,
        lastReviewed: Date? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.question = question
        self.answer = answer
        self.wrongAnswers = wrongAnswers
        self.isMastered = isMastered
        self.lastReviewed = lastReviewed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case documentId = "document_id"
        case question
        case answer
        case wrongAnswers = "wrong_answers"
        case isMastered = "is_mastered"
        case lastReviewed = "last_reviewed"
    }
}

// MARK: - Quiz Yardımcıları

extension FlashcardModel {
    /// Bu kartın quiz modunda kullanılabilir olup olmadığı
    /// (yani en az bir çeldirici içeriyor mu).
    var isQuizReady: Bool {
        guard let wrongAnswers else { return false }
        return !wrongAnswers.isEmpty
    }

    /// Doğru cevap + çeldiricilerin karıştırılmış hâli.
    /// Quiz ekranında şık sırasını rastgeleleştirmek için kullanılır.
    func shuffledOptions() -> [String] {
        var options = [answer]
        if let wrongAnswers { options.append(contentsOf: wrongAnswers) }
        return options.shuffled()
    }
}

// MARK: - Örnek Veri

extension FlashcardModel {
    static let preview = FlashcardModel(
        documentId: DocumentModel.preview.id,
        question: "Fransız İhtilali hangi yıl başlamıştır?",
        answer: "1789",
        wrongAnswers: ["1776", "1804", "1815"],
        isMastered: false,
        lastReviewed: nil
    )
}
