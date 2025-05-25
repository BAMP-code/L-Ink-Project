import SwiftUI

class AppViewModel: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var isAuthenticated: Bool = false
    @Published var isEditingNotebook: Bool = false
    
    // Add any other app-wide state properties here
} 
