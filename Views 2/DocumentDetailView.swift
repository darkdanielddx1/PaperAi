//
//  DocumentDetailView.swift
//  PaperAI
//
//  Kart çalışma ekranı: Tinder-tarzı üst üste binen kartlar.
//  Dokun → çevir (flip), sağa kaydır → "Öğrendim", sola kaydır → "Tekrar Et".
//

import SwiftUI

struct DocumentDetailView: View {

    @State private var viewModel: DocumentDetailViewModel

    /// Üstteki kartın sürükleme (drag) miktarı.
    @State private var dragOffset: CGSize = .zero

    /// Kaydırma kararının verildiği eşik (yatay piksel).
    private let swipeThreshold: CGFloat = 120

    init(viewModel: DocumentDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            content
        }
        .navigationTitle(viewModel.document.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadFlashcards() }
        .alert(
            "Bir hata oluştu",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - İçerik Yönlendirme

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingState
        } else if viewModel.isGenerating {
            generatingState
        } else if viewModel.hasNoFlashcards {
            emptyState
        } else if viewModel.isFinished {
            finishedState
        } else {
            studyDeck
        }
    }

    // MARK: - Kart Destesi

    private var studyDeck: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            ZStack {
                // Arkadaki bir sonraki kart (derinlik hissi).
                if viewModel.currentIndex + 1 < viewModel.flashcards.count {
                    let nextCard = viewModel.flashcards[viewModel.currentIndex + 1]
                    FlashcardView(card: nextCard)
                        .id(nextCard.id)
                        .scaleEffect(0.93)
                        .offset(y: 26)
                        .opacity(0.85)
                        .allowsHitTesting(false)
                }

                // En üstteki (etkileşimli) kart.
                if viewModel.currentIndex < viewModel.flashcards.count {
                    let topCard = viewModel.flashcards[viewModel.currentIndex]
                    FlashcardView(card: topCard)
                        .id(topCard.id)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width / 18)))
                        .overlay(swipeBadges)
                        .gesture(dragGesture)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 440)
            .padding(.horizontal, 28)

            Spacer(minLength: 12)

            actionHints
            bottomBar
        }
    }

    /// Kaydırma sırasında beliren "ÖĞRENDİM / TEKRAR" etiketleri.
    private var swipeBadges: some View {
        ZStack {
            badge(text: "ÖĞRENDİM", color: .green, systemImage: "checkmark.circle.fill")
                .opacity(Double(max(0, dragOffset.width) / swipeThreshold))
                .rotationEffect(.degrees(-12))
                .frame(maxWidth: .infinity, alignment: .leading)

            badge(text: "TEKRAR ET", color: .orange, systemImage: "arrow.counterclockwise.circle.fill")
                .opacity(Double(max(0, -dragOffset.width) / swipeThreshold))
                .rotationEffect(.degrees(12))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func badge(text: String, color: Color, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.headline.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(color, lineWidth: 2))
    }

    private var actionHints: some View {
        HStack(spacing: 40) {
            Label("Sola: Tekrar", systemImage: "arrow.left")
            Label("Sağa: Öğrendim", systemImage: "arrow.right")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.bottom, 12)
    }

    // MARK: - Alt Bar (Progress)

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(viewModel.completedCount)/\(viewModel.totalCount) Kart")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Label("\(viewModel.masteredCount) öğrenildi", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }

            ProgressView(value: viewModel.progress)
                .tint(.accentColor)
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Durum Ekranları

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Kartlar yükleniyor…")
                .foregroundStyle(.secondary)
        }
    }

    private var generatingState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 52))
                .foregroundStyle(.purple)
                .symbolEffect(.pulse)
            Text("Yapay zekâ kartları üretiyor…")
                .font(.title3.weight(.semibold))
            Text("Bu dokümandan bilgi kartları hazırlanıyor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView()
        }
        .padding(40)
        .multilineTextAlignment(.center)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Henüz kart üretilmemiş", systemImage: "rectangle.on.rectangle.slash")
        } description: {
            Text("Bu doküman için henüz bilgi kartı bulunmuyor.")
        }
    }

    private var finishedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Deste tamamlandı! 🎉")
                .font(.title2.weight(.bold))
            Text("\(viewModel.masteredCount)/\(viewModel.totalCount) kartı öğrendin.")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                withAnimation { viewModel.restart() }
            } label: {
                Label("Baştan Başla", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(40)
        .multilineTextAlignment(.center)
    }

    // MARK: - Sürükleme Jesti

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let width = value.translation.width
                if width > swipeThreshold {
                    performSwipe(.mastered)
                } else if width < -swipeThreshold {
                    performSwipe(.review)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func performSwipe(_ direction: SwipeDirection) {
        let flyAway: CGFloat = direction == .mastered ? 700 : -700
        withAnimation(.easeIn(duration: 0.28)) {
            dragOffset = CGSize(width: flyAway, height: -60)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(280))
            await viewModel.handleSwipe(direction)
            // Yeni üst kart için sürükleme durumunu (animasyonsuz) sıfırla.
            dragOffset = .zero
        }
    }
}

#Preview {
    NavigationStack {
        DocumentDetailView(
            viewModel: DashboardViewModel().makeDetailViewModel(
                for: DocumentModel(
                    userId: UserModel.preview.id,
                    title: "Önizleme Dokümanı",
                    rawText: "..."
                )
            )
        )
    }
}
