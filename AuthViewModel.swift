//
//  AuthViewModel.swift
//  L'Ink
//
//  Created by Daniela on 4/28/25.
//

import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check if user is already authenticated
        // This would typically check local storage or keychain
        checkAuthStatus()
    }
    
    func signUp(email: String, password: String, username: String) {
        // TODO: Implement actual sign up logic with your backend
        // This is a placeholder implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.currentUser = User(id: UUID().uuidString, email: email, username: username)
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) {
        // TODO: Implement actual sign in logic with your backend
        // This is a placeholder implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.currentUser = User(id: UUID().uuidString, email: email, username: "User")
            self.isAuthenticated = true
        }
    }
    
    func signOut() {
        // TODO: Implement actual sign out logic
        // This is a placeholder implementation
        currentUser = nil
        isAuthenticated = false
    }
    
    private func checkAuthStatus() {
        // TODO: Implement actual auth status check
        // This would typically check local storage or keychain
        isAuthenticated = false
    }
}

struct User {
    let id: String
    let email: String
    let username: String
} 
