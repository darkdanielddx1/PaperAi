//
//  WidgetDataManager.swift
//  PaperAI
//
//  Ana uygulama ile Ana Ekran Widget'ı arasındaki veri köprüsü.
//  İki hedef (app + widget extension) farklı sandbox'larda çalıştığı için
//  veriler App Group içindeki paylaşılan UserDefaults üzerinden aktarılır.
//
//  ÖNEMLİ: Bu dosya HEM ana uygulama HEM de PaperAIWidget hedefinin
//  "Target Membership"ine eklenmelidir. Aynı App Group ("group.com.yourname.PaperAI")
//  her iki hedefin Signing & Capabilities > App Groups bölümünde etkin olmalıdır.
//

import Foundation
import WidgetKit

/// Widget ile ana uygulama arasında flashcard verisini paylaşan yönetici.
struct WidgetDataManager: Sendable {

    /// Ortak erişim için paylaşılan örnek.
    static let shared = WidgetDataManager()

    /// App Group kimliği. Kendi bundle ID'nize göre güncelleyin.
    static let appGroupID = "group.com.yourname.PaperAI"

    /// Widget zaman çizelgesini yenilemek için kullanılan widget "kind".
    static let widgetKind = "PaperAIWidget"

    /// Paylaşılan alandaki JSON'un anahtarı.
    private let cardsKey = "widget_flashcards"

    /// Widget'ta gösterilecek maksimum kart sayısı.
    private let maxCards = 10

    // YENİ HALİ:
    // ESKİ HATA VEREN SATIRIN YERİNE BUKODU YAPIŞTIRIN:
    // Hem okumayı hem de yazmayı destekleyen, Swift 6 uyumlu yeni alanımız:
    private var defaults: UserDefaults? {
        get {
            UserDefaults(suiteName: "group.com.yigitstrives.PaperAI")
        }
        set {
            // Aşağıdaki atama satırının hata vermemesi için boş bir set bloğu bırakıyoruz
            // UserDefaults suiteName ile zaten tek bir havuzdan beslendiği için doğrudan atamaya gerek kalmaz
        }
    }

    init(appGroupID: String = WidgetDataManager.appGroupID) {
        self.defaults = UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Yazma (Ana Uygulama Tarafı)

    /// En kritik (öğrenilmemiş) kartları seçip paylaşılan alana yazar ve
    /// widget zaman çizelgesini yeniler.
    ///
    /// - Parameter cards: Değerlendirilecek kart havuzu (bir doküman ya da tümü).
    func saveCardsForWidget(_ cards: [FlashcardModel]) {
        guard let defaults else {
            assertionFailure("App Group (\(Self.appGroupID)) bulunamadı. Capabilities ayarını kontrol edin.")
            return
        }

        let selected = Self.selectCards(from: cards, limit: maxCards)

        do {
            let data = try JSONEncoder().encode(selected)
            defaults.set(data, forKey: cardsKey)
            // Değişikliği anında widget'a yansıt.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("WidgetDataManager encode hatası: \(error.localizedDescription)")
        }
    }

    /// Paylaşılan alandaki tüm widget verisini temizler.
    func clearWidgetData() {
        defaults?.removeObject(forKey: cardsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Okuma (Widget Tarafı)

    /// Paylaşılan alandan kartları decode ederek döndürür.
    /// - Returns: Kayıtlı kartlar; yoksa boş dizi.
    func fetchCardsForWidget() -> [FlashcardModel] {
        guard let defaults, let data = defaults.data(forKey: cardsKey) else {
            return []
        }
        return (try? JSONDecoder().decode([FlashcardModel].self, from: data)) ?? []
    }

    // MARK: - Kart Seçim Mantığı

    /// Havuzdan en kritik kartları seçer: önce öğrenilmemişler, en eski/hiç
    /// tekrar edilmemişler öne alınır.
    static func selectCards(from cards: [FlashcardModel], limit: Int = 10) -> [FlashcardModel] {
        let unmastered = cards.filter { !$0.isMastered }
        // Hepsi öğrenildiyse yine de örnek göstermek için tüm havuza düş.
        let pool = unmastered.isEmpty ? cards : unmastered

        let sorted = pool.sorted { lhs, rhs in
            switch (lhs.lastReviewed, rhs.lastReviewed) {
            case (nil, nil): return false
            case (nil, _):   return true          // hiç tekrar edilmemiş önce gelir
            case (_, nil):   return false
            case let (l?, r?): return l < r        // en eski tekrar önce gelir
            }
        }
        return Array(sorted.prefix(limit))
    }
}
