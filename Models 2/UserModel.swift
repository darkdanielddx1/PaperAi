//
//  UserModel.swift
//  PaperAI
//
//  Kullanıcı hesabını temsil eden veri modeli.
//  Firebase/Supabase Auth ve RevenueCat ile uyumludur.
//

import Foundation

/// Uygulamadaki bir kullanıcıyı temsil eder.
///
/// `id` alanı, Firebase Auth `uid` veya Supabase `auth.users.id` değeriyle eşleşir.
/// Bu yüzden `UUID` yerine `String` kullanılır.
struct UserModel: Codable, Identifiable, Hashable {

    /// Auth sağlayıcısından (Firebase/Supabase) gelen benzersiz kullanıcı kimliği.
    let id: String

    /// Kullanıcının e-posta adresi.
    var email: String

    /// Hesabın oluşturulma tarihi.
    var createdAt: Date

    /// RevenueCat üzerinden premium abonelik durumu.
    var isPremium: Bool

    init(
        id: String,
        email: String,
        createdAt: Date = Date(),
        isPremium: Bool = false
    ) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
        self.isPremium = isPremium
    }

    /// Supabase/Firestore sütun isimleri snake_case olduğu için eşleştirme.
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case isPremium = "is_premium"
    }
}

// MARK: - Örnek Veri

extension UserModel {
    /// SwiftUI önizlemeleri ve testler için örnek kullanıcı.
    static let preview = UserModel(
        id: "user_preview_001",
        email: "ogrenci@paperai.app",
        createdAt: Date(timeIntervalSince1970: 1_710_000_000),
        isPremium: true
    )
}
