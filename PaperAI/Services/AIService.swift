//
//  AIService.swift
//  PaperAI
//
//  Döküman metnini OpenAI Chat Completions API'sine gönderip
//  soru-cevap formatında bilgi kartları (FlashcardModel) üreten servis.
//
//  Not: Gerçek API çağrısı `OpenAIService` içindedir. Uygulama, API anahtarı
//  girilene kadar da çalışsın diye `DashboardViewModel` varsayılan olarak
//  `MockAIService` kullanır.
//

import Foundation

/// Ham metinden bilgi kartı üreten AI katmanının soyutlaması.
protocol AIServiceProtocol: Sendable {
    /// Verilen metinden bilgi kartları üretir.
    /// - Parameters:
    ///   - rawText: OCR/PDF'ten çıkarılmış ham metin.
    ///   - documentId: Üretilen kartların bağlanacağı doküman kimliği.
    /// - Returns: Üretilmiş `FlashcardModel` dizisi.
    func generateFlashcards(from rawText: String, documentId: UUID) async throws -> [FlashcardModel]
}

// MARK: - Hatalar

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case emptyDocument
    case invalidResponse
    case server(status: Int, message: String)
    case decodingFailed(String)
    case noFlashcardsGenerated

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API anahtarı ayarlanmamış. Lütfen AIService içindeki anahtarı güncelleyin."
        case .emptyDocument:
            return "Doküman metni boş. Kart üretmek için geçerli bir metin gerekli."
        case .invalidResponse:
            return "Sunucudan beklenmeyen bir yanıt alındı."
        case .server(let status, let message):
            return "OpenAI hatası (\(status)): \(message)"
        case .decodingFailed(let detail):
            return "Yapay zekâ yanıtı çözümlenemedi: \(detail)"
        case .noFlashcardsGenerated:
            return "Bu metinden bilgi kartı üretilemedi. Daha fazla içerik içeren bir doküman deneyin."
        }
    }
}

// MARK: - OpenAI Implementasyonu

/// OpenAI Chat Completions API'sini kullanan gerçek servis.
import Foundation

struct OpenAIService: AIServiceProtocol {

    private let apiKey: String
    private let model: String
    private let urlSession: URLSession
    // Groq API Endpoint adresi tanımlandı:
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    init(
        apiKey: String = "giris-yapilmadi",
        model: String = "openai/gpt-oss-120b", // <-- Hataya sebep olan eski model güncel Groq ID'si ile değiştirildi
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.urlSession = urlSession
    }

    private var systemPrompt: String {
        """
        Sana gönderilen döküman metnini oku. Bu metinden en kritik bilgileri içeren, \
        soru-cevap formatında flashcard'lar üret. Çıktıyı kesinlikle şu JSON formatında \
        ver, ekstra hiçbir metin veya markdown (```json gibi) ekleme: \
        [ { "question": "...", "answer": "...", "wrongAnswers": ["...", "...", "..."] } ]
        """
    }

    func generateFlashcards(from rawText: String, documentId: UUID) async throws -> [FlashcardModel] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.emptyDocument }
        guard apiKey != "YOUR_OPENAI_API_KEY", !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        // 1) İstek gövdesini hazırla.
        let requestBody = ChatRequest(
            model: model,
            messages: [
                ChatRequest.Message(role: "system", content: systemPrompt),
                ChatRequest.Message(role: "user", content: trimmed)
            ],
            temperature: 0.4
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        // 2) İsteği gönder.
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Bilinmeyen hata"
            throw AIServiceError.server(status: httpResponse.statusCode, message: message)
        }

        // 3) API zarfını çöz, içindeki metni al.
        let completion: ChatResponse
        do {
            completion = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw AIServiceError.decodingFailed("API zarfı: \(error.localizedDescription)")
        }
        guard let content = completion.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }

        // 4) Metnin içindeki JSON'u güvenli biçimde ayıkla ve decode et.
        let cards = try Self.decodeGeneratedCards(from: content)
        let flashcards = cards.map { $0.toFlashcard(documentId: documentId) }
        guard !flashcards.isEmpty else { throw AIServiceError.noFlashcardsGenerated }
        return flashcards
    }

    // MARK: JSON Ayıklama & Decode

    /// Modelin döndürdüğü metinden kart dizisini güvenle çıkarır.
    ///
    /// Sistem mesajı markdown yasaklasa da, olası ``` çitleri veya sarmalayıcı
    /// obje (`{"flashcards": [...]}`) durumlarına karşı savunmacı davranır.
    static func decodeGeneratedCards(from content: String) throws -> [GeneratedCard] {
        let jsonData = sanitizedJSONData(from: content)
        let decoder = JSONDecoder()

        // 1) Doğrudan dizi olarak dene.
        if let cards = try? decoder.decode([GeneratedCard].self, from: jsonData) {
            return cards
        }
        // 2) {"flashcards": [...]} sarmalayıcısını dene.
        if let wrapper = try? decoder.decode(GeneratedCardWrapper.self, from: jsonData) {
            return wrapper.flashcards
        }
        let raw = String(data: jsonData, encoding: .utf8) ?? content
        throw AIServiceError.decodingFailed("Beklenen kart dizisi bulunamadı. Yanıt: \(raw.prefix(200))")
    }

    /// Metinden ``` çitlerini temizler ve ilk `[`...son `]` aralığını alır.
    private static func sanitizedJSONData(from content: String) -> Data {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]") {
            text = String(text[start...end])
        }
        return Data(text.utf8)
    }
}

// MARK: - İstek / Yanıt Modelleri (OpenAI)

private struct ChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String
    }
}

/// AI'ın ürettiği ham kart (JSON) modeli. `FlashcardModel`'e dönüştürülür.
struct GeneratedCard: Codable {
    let question: String
    let answer: String
    let wrongAnswers: [String]?

    func toFlashcard(documentId: UUID) -> FlashcardModel {
        FlashcardModel(
            documentId: documentId,
            question: question,
            answer: answer,
            wrongAnswers: wrongAnswers,
            isMastered: false,
            lastReviewed: nil
        )
    }
}

private struct GeneratedCardWrapper: Decodable {
    let flashcards: [GeneratedCard]
}

// MARK: - Mock Implementasyonu

/// API anahtarı olmadan UI'ı test etmek için sahte AI servisi.
struct MockAIService: AIServiceProtocol {

    var simulatedLatency: Duration = .seconds(2)

    func generateFlashcards(from rawText: String, documentId: UUID) async throws -> [FlashcardModel] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.emptyDocument }

        if simulatedLatency > .zero {
            try await Task.sleep(for: simulatedLatency)
        }

        // Metnin ilk cümlesinden basit bir örnek kart üretir + sabit örnekler.
        let firstSentence = trimmed
            .split(whereSeparator: { ".!?\n".contains($0) })
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? "Bu doküman"

        return [
            FlashcardModel(
                documentId: documentId,
                question: "Bu dokümanın ana konusu nedir?",
                answer: firstSentence,
                wrongAnswers: ["İlgisiz konu A", "İlgisiz konu B", "İlgisiz konu C"]
            ),
            FlashcardModel(
                documentId: documentId,
                question: "Metindeki en önemli kavram hangi bölümde geçer?",
                answer: "Giriş bölümünde vurgulanır.",
                wrongAnswers: ["Sonuç bölümünde", "Kaynakçada", "Dipnotta"]
            ),
            FlashcardModel(
                documentId: documentId,
                question: "Bu içerik hangi çalışma formatına uygundur?",
                answer: "Soru-cevap (flashcard) tekrarı",
                wrongAnswers: ["Sadece dinleme", "Yalnızca video", "Grup tartışması"]
            )
        ]
    }
}
