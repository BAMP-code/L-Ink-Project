import SwiftUI
import Combine

class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    @Published var isInitialized = false
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupMetadataSync()
    }
    
    private func setupMetadataSync() {
        // Handle metadata synchronization
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.syncMetadata()
            }
            .store(in: &cancellables)
    }
    
    func syncMetadata() {
        // Perform any necessary metadata synchronization
        DispatchQueue.global(qos: .utility).async {
            // Metadata sync operations
        }
    }
    
    func initialize() {
        guard !isInitialized else { return }
        
        DispatchQueue.main.async {
            self.isInitialized = true
        }
    }
} 