import SwiftUI

@main
struct PaperAIApp: App {
    // DashboardViewModel @MainActor-isolated olduğu için @State ile güvenle başlatıyoruz
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var path = NavigationPath()
    
    var body: some Scene {
        WindowGroup {
            // DashboardView zaten içeride kendi NavigationStack'ine sahip, path'i binding olarak veriyoruz
            DashboardView(viewModel: dashboardViewModel, path: $path)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    // Widget deep link'ini kusursuz çözen fonksiyon
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "paperai",
              url.host == "document",
              let documentIdString = url.pathComponents.last,
              let documentId = UUID(uuidString: documentIdString) else {
            return
        }
        
        Task { @MainActor in
            // ViewModel'daki doğru asenkron metodu (loadDocuments) çağırıyoruz
            await dashboardViewModel.loadDocuments()
            
            // Eğer döküman listede varsa navigasyon yığınını sıfırlayıp detayına uçuruyoruz
            if let document = dashboardViewModel.documents.first(where: { $0.id == documentId }) {
                path = NavigationPath()
                path.append(document)
            }
        }
    }
}
