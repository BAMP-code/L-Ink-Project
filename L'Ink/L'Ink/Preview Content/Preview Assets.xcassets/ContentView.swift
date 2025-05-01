import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                SignUpView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NotebookFeedView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            NotebookSpaceView()
                .tabItem {
                    Label("Space", systemImage: "book")
                }
            
            NotebookLockerView()
                .tabItem {
                    Label("Locker", systemImage: "lock")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
} 