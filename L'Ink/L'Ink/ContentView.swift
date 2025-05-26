import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appConfig: AppConfig
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if appConfig.isInitialized {
                    if authViewModel.isAuthenticated {
                        MainTabView()
                            .environmentObject(appViewModel)
                    } else {
                        SignInView()
                    }
                } else {
                    ProgressView()
                        .onAppear {
                            appConfig.initialize()
                        }
                }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var hideTabBar = false
    
    var body: some View {
        TabView(selection: $appViewModel.selectedTab) {
            NotebookFeedView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            NotebookSpaceView()
                .tabItem {
                    Label("Notebook Space", systemImage: "book")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .opacity(hideTabBar ? 0 : 1)
        .animation(.easeInOut, value: hideTabBar)
    }
}
