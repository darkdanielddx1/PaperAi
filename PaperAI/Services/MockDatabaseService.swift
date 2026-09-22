//
//  MockDatabaseService.swift
//  PaperAI
//
//  Gerçek backend (Firebase/Supabase) bağlanana kadar UI'ı canlı test etmek
//  için kullanılan, bellek-içi (in-memory) sahte veritabanı.
//
//  `actor` olarak yazılmıştır: mutable state'e eşzamanlı erişim otomatik
//  olarak serialize edilir, böylece `Sendable` protokolü güvenle karşılanır.
//

import Foundation

/// `DatabaseServiceProtocol`'ün bellek-içi sahte implementasyonu.
///
/// İçinde zengin örnek veri (tarih ve yazılım ders notları + bunlardan
/// üretilmiş bilgi kartları) barındırır. Ağ gecikmesini simüle etmek için
/// her çağrıda kısa bir bekleme uygular.
actor MockDatabaseService: DatabaseServiceProtocol {

    // MARK: - Durum (State)

    private var documents: [DocumentModel]
    private var flashcards: [UUID: [FlashcardModel]]  // documentId -> kartlar

    /// Ağ gecikmesi simülasyonu (saniye). Test için 0 verilebilir.
    private let simulatedLatency: Duration

    // MARK: - Kurulum

    init(simulatedLatency: Duration = .milliseconds(400)) {
        self.simulatedLatency = simulatedLatency

        // Örnek veri seti kuruluyor.
        let seed = MockDatabaseService.makeSeedData()
        self.documents = seed.documents
        self.flashcards = seed.flashcardsByDocument
    }

    // MARK: - Dokümanlar

    func fetchDocuments(for userId: String) async throws -> [DocumentModel] {
        try await simulateNetwork()
        return documents
            .filter { $0.userId == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func createDocument(_ document: DocumentModel) async throws -> DocumentModel {
        try await simulateNetwork()
        documents.append(document)
        // Yeni dokümanın kartları henüz yok; boş dizi ile başlat.
        if flashcards[document.id] == nil {
            flashcards[document.id] = []
        }
        return document
    }

    func deleteDocument(id: UUID) async throws {
        try await simulateNetwork()
        guard documents.contains(where: { $0.id == id }) else {
            throw DatabaseError.documentNotFound(id)
        }
        documents.removeAll { $0.id == id }
        // Cascade delete: dokümana bağlı kartlar da silinir.
        flashcards[id] = nil
    }

    // MARK: - Bilgi Kartları

    func fetchFlashcards(for documentId: UUID) async throws -> [FlashcardModel] {
        try await simulateNetwork()
        guard documents.contains(where: { $0.id == documentId }) else {
            throw DatabaseError.documentNotFound(documentId)
        }
        return flashcards[documentId] ?? []
    }

    func addFlashcards(_ cards: [FlashcardModel], to documentId: UUID) async throws {
        try await simulateNetwork()
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else {
            throw DatabaseError.documentNotFound(documentId)
        }
        flashcards[documentId, default: []].append(contentsOf: cards)
        documents[index].flashcardIds.append(contentsOf: cards.map(\.id))
    }

    @discardableResult
    func toggleFlashcardMastery(flashcardId: UUID) async throws -> FlashcardModel {
        try await simulateNetwork()

        for (documentId, cards) in flashcards {
            guard let index = cards.firstIndex(where: { $0.id == flashcardId }) else {
                continue
            }
            var updated = cards[index]
            updated.isMastered.toggle()
            updated.lastReviewed = Date()
            flashcards[documentId]?[index] = updated
            return updated
        }

        throw DatabaseError.flashcardNotFound(flashcardId)
    }

    @discardableResult
    func setFlashcardMastery(flashcardId: UUID, isMastered: Bool) async throws -> FlashcardModel {
        try await simulateNetwork()

        for (documentId, cards) in flashcards {
            guard let index = cards.firstIndex(where: { $0.id == flashcardId }) else {
                continue
            }
            var updated = cards[index]
            updated.isMastered = isMastered
            updated.lastReviewed = Date()
            flashcards[documentId]?[index] = updated
            return updated
        }

        throw DatabaseError.flashcardNotFound(flashcardId)
    }

    // MARK: - Yardımcılar

    private func simulateNetwork() async throws {
        guard simulatedLatency > .zero else { return }
        try await Task.sleep(for: simulatedLatency)
    }
}

// MARK: - Örnek Veri Üretimi (Seed Data)

extension MockDatabaseService {

    /// Sabit bir kullanıcı için örnek doküman ve kartları üretir.
    fileprivate static func makeSeedData() -> (
        documents: [DocumentModel],
        flashcardsByDocument: [UUID: [FlashcardModel]]
    ) {
        let userId = UserModel.preview.id

        // 1) TARİH DERS NOTU ---------------------------------------------------
        let historyDocId = UUID()
        let historyCards: [FlashcardModel] = [
            FlashcardModel(
                documentId: historyDocId,
                question: "Fransız İhtilali hangi yıl başlamıştır?",
                answer: "1789",
                wrongAnswers: ["1776", "1804", "1815"],
                isMastered: true,
                lastReviewed: Date(timeIntervalSince1970: 1_711_000_000)
            ),
            FlashcardModel(
                documentId: historyDocId,
                question: "Bastille Hapishanesi hangi tarihte basıldı?",
                answer: "14 Temmuz 1789",
                wrongAnswers: ["4 Temmuz 1776", "1 Ocak 1789", "2 Aralık 1804"],
                isMastered: false
            ),
            FlashcardModel(
                documentId: historyDocId,
                question: "\"İnsan ve Yurttaş Hakları Bildirisi\" hangi ilkeleri savunur?",
                answer: "Özgürlük, eşitlik ve mülkiyet haklarını.",
                wrongAnswers: [
                    "Mutlak monarşinin üstünlüğünü.",
                    "Kilisenin devlet üzerindeki hakimiyetini.",
                    "Feodal ayrıcalıkların korunmasını."
                ],
                isMastered: false
            ),
            FlashcardModel(
                documentId: historyDocId,
                question: "Fransız İhtilali'nin evrensel sloganı nedir?",
                answer: "Özgürlük, Eşitlik, Kardeşlik",
                wrongAnswers: [
                    "Kan ve Demir",
                    "Ekmek ve Barış",
                    "Tanrı, Vatan, Aile"
                ],
                isMastered: false
            )
        ]
        let historyDoc = DocumentModel(
            id: historyDocId,
            userId: userId,
            title: "Fransız İhtilali — Tarih Ders Notu",
            rawText: """
            1789 yılında başlayan Fransız İhtilali, mutlak monarşinin sona ermesine \
            ve modern demokrasinin temellerinin atılmasına yol açmıştır. 14 Temmuz 1789'da \
            halkın Bastille Hapishanesi'ni basmasıyla devrim fiilen başlamıştır. Aynı yıl \
            yayımlanan "İnsan ve Yurttaş Hakları Bildirisi" özgürlük, eşitlik ve mülkiyet \
            haklarını güvence altına almıştır. Devrimin sloganı "Özgürlük, Eşitlik, \
            Kardeşlik" tüm dünyaya yayılmıştır.
            """,
            createdAt: Date(timeIntervalSince1970: 1_711_100_000),
            flashcardIds: historyCards.map(\.id)
        )

        // 2) YAZILIM DERS NOTU -------------------------------------------------
        let swiftDocId = UUID()
        let swiftCards: [FlashcardModel] = [
            FlashcardModel(
                documentId: swiftDocId,
                question: "Swift'te 'value type' olan iki temel yapı nedir?",
                answer: "struct ve enum",
                wrongAnswers: ["class ve actor", "protocol ve class", "closure ve class"],
                isMastered: true,
                lastReviewed: Date(timeIntervalSince1970: 1_711_200_000)
            ),
            FlashcardModel(
                documentId: swiftDocId,
                question: "async/await ne işe yarar?",
                answer: "Asenkron kodu, senkron gibi okunabilir şekilde yazmayı sağlar.",
                wrongAnswers: [
                    "Belleği otomatik olarak temizler.",
                    "UI bileşenlerini otomatik oluşturur.",
                    "Ağ bağlantısını şifreler."
                ],
                isMastered: false
            ),
            FlashcardModel(
                documentId: swiftDocId,
                question: "MVVM mimarisinde ViewModel'in görevi nedir?",
                answer: "View için sunum mantığını ve durumu (state) yönetmek.",
                wrongAnswers: [
                    "Veritabanı tablolarını oluşturmak.",
                    "Doğrudan UIKit view'larını çizmek.",
                    "Ağ soketlerini yönetmek."
                ],
                isMastered: false
            ),
            FlashcardModel(
                documentId: swiftDocId,
                question: "'actor' tipi hangi sorunu çözer?",
                answer: "Veri yarışlarını (data race) önleyerek eşzamanlı erişimi güvenli kılar.",
                wrongAnswers: [
                    "Derleme süresini kısaltır.",
                    "Otomatik arayüz testi yapar.",
                    "JSON'u otomatik parse eder."
                ],
                isMastered: false
            ),
            FlashcardModel(
                documentId: swiftDocId,
                question: "Codable protokolü hangi iki protokolün birleşimidir?",
                answer: "Encodable ve Decodable",
                wrongAnswers: [
                    "Hashable ve Equatable",
                    "Identifiable ve Sendable",
                    "Comparable ve CustomStringConvertible"
                ],
                isMastered: false
            )
        ]
        let swiftDoc = DocumentModel(
            id: swiftDocId,
            userId: userId,
            title: "Swift & Modern iOS — Yazılım Ders Notu",
            rawText: """
            Swift, Apple ekosisteminin modern programlama dilidir. Değer tipleri (value \
            types) olan struct ve enum, referans tiplerine (class) göre daha güvenli ve \
            öngörülebilir davranış sunar. Swift Concurrency ile gelen async/await, asenkron \
            işlemleri senkron kod okunabilirliğinde yazmayı mümkün kılar. Veri yarışlarını \
            önlemek için 'actor' tipi kullanılır. MVVM mimarisinde ViewModel, View için \
            sunum mantığını ve durumu yönetir; Model ise veriyi temsil eder. Codable \
            protokolü (Encodable + Decodable) JSON dönüşümlerini kolaylaştırır.
            """,
            createdAt: Date(timeIntervalSince1970: 1_711_300_000),
            flashcardIds: swiftCards.map(\.id)
        )

        // 3) BİYOLOJİ DERS NOTU (henüz kartı üretilmemiş doküman) --------------
        let bioDocId = UUID()
        let bioDoc = DocumentModel(
            id: bioDocId,
            userId: userId,
            title: "Hücre Biyolojisi — Ham Tarama",
            rawText: """
            Hücre, canlıların yapısal ve işlevsel temel birimidir. Prokaryot hücrelerde \
            çekirdek zarı bulunmazken, ökaryot hücrelerde genetik materyal çekirdek zarı \
            ile çevrilidir. Mitokondri hücrenin enerji santralidir ve ATP üretir.
            """,
            createdAt: Date(timeIntervalSince1970: 1_711_400_000),
            flashcardIds: []
        )

        let documents = [bioDoc, swiftDoc, historyDoc]
        let flashcardsByDocument: [UUID: [FlashcardModel]] = [
            historyDocId: historyCards,
            swiftDocId: swiftCards,
            bioDocId: []
        ]

        return (documents, flashcardsByDocument)
    }
}
