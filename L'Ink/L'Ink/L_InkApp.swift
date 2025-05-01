import SwiftUI

@main
struct LInkApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appConfig = AppConfig.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(appConfig)
                .preferredColorScheme(.light)
                .onAppear {
                    // Optimize initial rendering
                    DispatchQueue.main.async {
                        appConfig.initialize()
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App became active
                appConfig.syncMetadata()
            case .inactive:
                // App became inactive
                break
            case .background:
                // App went to background
                break
            @unknown default:
                break
            }
        }
    }
} 
