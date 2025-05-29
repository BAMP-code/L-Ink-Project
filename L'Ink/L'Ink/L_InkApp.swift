import SwiftUI
import FirebaseCore
import FirebaseStorage
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        // Configure App Check with a debug provider for the simulator
        #if targetEnvironment(simulator)
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif
        return true
    }
}

@main
struct LInkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appConfig = AppConfig.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(appConfig)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appConfig.syncMetadata()
            }
        }
    }
}
