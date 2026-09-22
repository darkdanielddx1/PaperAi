//
//  DocumentRowView.swift
//  PaperAI
//
//  Dashboard listesinde tek bir dokümanı temsil eden temiz kart bileşeni.
//

import SwiftUI

/// Doküman listesinde gösterilen satır kartı.
///
/// İçerik: başlık, oluşturulma tarihi ve kart (flashcard) sayısı.
struct DocumentRowView: View {

    let document: DocumentModel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack(spacing: 16) {
            // Sol taraftaki ikon rozeti.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.accentColor.opacity(0.85), .accentColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label(Self.dateFormatter.string(from: document.createdAt),
                          systemImage: "calendar")

                    Label("\(document.flashcardIds.count) kart",
                          systemImage: "rectangle.on.rectangle.angled")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        VStack(spacing: 12) {
            DocumentRowView(document: .preview)
            DocumentRowView(
                document: DocumentModel(
                    userId: "u1",
                    title: "Swift & Modern iOS Ders Notu",
                    rawText: "...",
                    flashcardIds: [UUID(), UUID(), UUID()]
                )
            )
        }
        .padding()
    }
}
