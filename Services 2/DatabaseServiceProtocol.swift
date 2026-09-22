//
//  DatabaseServiceProtocol.swift
//  PaperAI
//
//  Veritabanı katmanının soyutlaması.
//  Mock, Firebase ve Supabase implementasyonları bu protokolü uygular;
//  böylece ViewModel'ler somut backend'e bağımlı kalmaz (Dependency Inversion).
//

import Foundation

/// Uygulamanın ihtiyaç duyduğu tüm veri erişim işlemlerini tanımlar.
///
/// Tüm fonksiyonlar `async` ve `throws`'dur; Swift Concurrency ile
/// ağ/disk işlemleri sırasında UI bloklanmaz.
///
/// - Important: `Sendable` olarak işaretlidir; farklı actor/thread'lerden
///   güvenle çağrılabilir.
protocol DatabaseServiceProtocol: Sendable {

    // MARK: Dokümanlar

    /// Belirtilen kullanıcıya ait tüm dokümanları getirir.
    /// - Parameter userId: Auth kullanıcı kimliği.
    /// - Returns: Oluşturulma tarihine göre (yeniden eskiye) sıralı dokümanlar.
    func fetchDocuments(for userId: String) async throws -> [DocumentModel]

    /// Yeni bir doküman oluşturur ve kalıcı hale getirir.
    /// - Parameter document: Kaydedilecek doküman.
    /// - Returns: Backend tarafından işlenmiş (kaydedilmiş) doküman.
    @discardableResult
    func createDocument(_ document: DocumentModel) async throws -> DocumentModel

    /// Bir dokümanı ve ona bağlı tüm bilgi kartlarını siler (cascade delete).
    /// - Parameter id: Silinecek dokümanın kimliği.
    func deleteDocument(id: UUID) async throws

    // MARK: Bilgi Kartları

    /// Belirtilen dokümana ait tüm bilgi kartlarını getirir.
    /// - Parameter documentId: Dokümanın kimliği.
    func fetchFlashcards(for documentId: UUID) async throws -> [FlashcardModel]

    /// Üretilmiş kartları bir dokümana ekler ve dokümanın `flashcardIds`
    /// listesini günceller (AI kart üretimi sonrası kalıcılaştırma).
    /// - Parameters:
    ///   - flashcards: Eklenecek kartlar.
    ///   - documentId: Kartların bağlanacağı doküman.
    func addFlashcards(_ flashcards: [FlashcardModel], to documentId: UUID) async throws

    /// Bir kartın "öğrenildi" (mastered) durumunu tersine çevirir.
    /// - Parameter flashcardId: Güncellenecek kartın kimliği.
    /// - Returns: Güncellenmiş kartın son hâli.
    @discardableResult
    func toggleFlashcardMastery(flashcardId: UUID) async throws -> FlashcardModel

    /// Bir kartın "öğrenildi" durumunu doğrudan belirtilen değere ayarlar.
    /// (Tinder-tarzı sağa/sola kaydırmada belirsiz toggle yerine kullanılır.)
    /// - Parameters:
    ///   - flashcardId: Güncellenecek kartın kimliği.
    ///   - isMastered: Yeni öğrenilme durumu.
    /// - Returns: Güncellenmiş kartın son hâli.
    @discardableResult
    func setFlashcardMastery(flashcardId: UUID, isMastered: Bool) async throws -> FlashcardModel
}

/// Veritabanı katmanında oluşabilecek hatalar.
enum DatabaseError: LocalizedError {
    case documentNotFound(UUID)
    case flashcardNotFound(UUID)
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .documentNotFound(let id):
            return "Doküman bulunamadı: \(id)"
        case .flashcardNotFound(let id):
            return "Bilgi kartı bulunamadı: \(id)"
        case .userNotAuthenticated:
            return "Bu işlem için oturum açmanız gerekiyor."
        }
    }
}
