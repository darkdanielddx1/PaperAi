//
//  DashboardView.swift
//  PaperAI
//
//  Ana ekran: kullanıcının dokümanlarını listeler, silme ve yeni doküman
//  ekleme (FAB) işlevlerini sunar. Bir dokümana dokununca kart çalışma
//  ekranına (DocumentDetailView) geçilir.
//

import SwiftUI

struct DashboardView: View {

    @State private var viewModel: DashboardViewModel

    /// Doküman ekleme modalının (kamera/PDF) görünürlüğü.
    @State private var showUploadSheet = false

    /// Bağımsız kullanım/önizleme için dahili navigasyon yolu.
    @State private var internalPath = NavigationPath()

    /// App seviyesinden (deep link için) enjekte edilen navigasyon yolu.
    private let externalPath: Binding<NavigationPath>?

    init(
        viewModel: DashboardViewModel = DashboardViewModel(),
        path: Binding<NavigationPath>? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.externalPath = path
    }

    /// Aktif navigasyon yolu: dışarıdan verildiyse onu, yoksa dahili olanı kullanır.
    private var pathBinding: Binding<NavigationPath> {
        externalPath ?? $internalPath
    }

    var body: some View {
        NavigationStack(path: pathBinding) {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        loadingState
                    } else if viewModel.isEmpty {
                        emptyState
                    } else {
                        documentList
                    }
                }

                floatingAddButton
            }
            .navigationTitle("PaperAI")
            .navigationDestination(for: DocumentModel.self) { document in
                DocumentDetailView(viewModel: viewModel.makeDetailViewModel(for: document))
            }
            .toolbar { premiumBadge }
            .task {
                if viewModel.documents.isEmpty {
                    await viewModel.loadDocuments()
                }
            }
            .refreshable { await viewModel.loadDocuments() }
            .sheet(isPresented: $showUploadSheet) {
                UploadSheetView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
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
    }

    // MARK: - Premium Rozeti (Header)

    @ToolbarContentBuilder
    private var premiumBadge: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.currentUser.isPremium {
                Label("Premium", systemImage: "crown.fill")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .accessibilityLabel("Premium üye")
            } else {
                Image(systemName: "star")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Ücretsiz üye")
            }
        }
    }

    // MARK: - Doküman Listesi

    private var documentList: some View {
        List {
            ForEach(viewModel.documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteDocument(document) }
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Boş Durum

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Henüz doküman yok", systemImage: "doc.badge.plus")
        } description: {
            Text("İlk dökümanını ekle; yapay zekâ senin için bilgi kartları hazırlasın.")
        } actions: {
            Button {
                showUploadSheet = true
            } label: {
                Label("İlk dökümanını ekle", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }

    // MARK: - Yükleniyor

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Dokümanların yükleniyor…")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Floating Action Button (FAB)

    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showUploadSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .frame(width: 62, height: 62)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: .accentColor.opacity(0.45), radius: 12, x: 0, y: 6)
                }
                .padding(24)
            }
        }
    }
}

#Preview("Premium — Dolu") {
    DashboardView()
}

#Preview("Boş Durum") {
    // Seed verisi olmayan (farklı id'li) bir kullanıcı → boş durum gösterilir.
    let emptyUser = UserModel(id: "empty_user", email: "yeni@paperai.app", isPremium: false)
    return DashboardView(viewModel: DashboardViewModel(currentUser: emptyUser))
}
