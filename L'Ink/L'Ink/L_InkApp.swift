import SwiftUI
import FirebaseCore
import FirebaseStorage

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
                if authViewModel.isAuthenticated {
                    // Replace with your main logged-in view
                    Text("Welcome, \(authViewModel.currentUser?.username ?? "")")
                } else {
                    SignInView()
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(appConfig)
            .preferredColorScheme(.light)
            .onAppear {
                DispatchQueue.main.async {
                    appConfig.initialize()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appConfig.syncMetadata()
            }
        }
    }
}
