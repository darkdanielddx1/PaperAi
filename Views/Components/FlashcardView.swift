//
//  FlashcardView.swift
//  PaperAI
//
//  Tek bir bilgi kartını gösteren, dokununca 3D dönen (flip) kart bileşeni.
//  Kaydırma (swipe) mantığı üst ekran (DocumentDetailView) tarafından yönetilir.
//

import SwiftUI

/// Ön yüzünde soru, arka yüzünde cevap bulunan çevrilebilir bilgi kartı.
///
/// Karta dokunulduğunda Y ekseni etrafında 180° dönerek arka yüzü gösterir.
/// Kart değiştiğinde (`.id(card.id)`) çevirme durumu otomatik sıfırlanır.
struct FlashcardView: View {

    let card: FlashcardModel

    @State private var isFlipped = false

    var body: some View {
        ZStack {
            frontFace
                .opacity(isFlipped ? 0 : 1)

            backFace
                .opacity(isFlipped ? 1 : 0)
                // Arka yüz aynalanmasın diye içeriği geri çeviriyoruz.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
    }

    // MARK: - Ön Yüz (Soru)

    private var frontFace: some View {
        cardContainer(
            gradient: [Color(red: 0.28, green: 0.36, blue: 0.98),
                       Color(red: 0.45, green: 0.30, blue: 0.95)]
        ) {
            VStack(spacing: 20) {
                Text("SORU")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))

                Text(card.question)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)

                Label("Cevabı görmek için dokun", systemImage: "hand.tap.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // MARK: - Arka Yüz (Cevap)

    private var backFace: some View {
        cardContainer(
            gradient: [Color(red: 0.06, green: 0.72, blue: 0.51),
                       Color(red: 0.02, green: 0.55, blue: 0.62)]
        ) {
            VStack(spacing: 20) {
                Text("CEVAP")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.75))

                Text(card.answer)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)

                if card.isMastered {
                    Label("Öğrenildi", systemImage: "checkmark.seal.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Ortak Kart Kabuğu

    private func cardContainer<Content: View>(
        gradient: [Color],
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 12)
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        FlashcardView(card: .preview)
            .frame(height: 420)
            .padding(32)
    }
}
