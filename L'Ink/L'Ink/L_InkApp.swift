import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct LInkApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appConfig = AppConfig.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationView {
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
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                appConfig.syncMetadata()
            case .inactive:
                break
            case .background:
                break
            @unknown default:
                break
            }
        }
    }
}
