//
//  AuthViewModel.swift
//  L'Ink
//
//  Created by Daniela on 4/28/25.
//

import SwiftUI
import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    
    init() {
        // For testing, create a default user with ID "bamp"
        Task {
            await createDefaultUser()
        }
    }
    
    private func createDefaultUser() async {
        do {
            let userDoc = try await db.collection("users").document("bamp").getDocument()
            
            if !userDoc.exists {
                // Create default user
                let defaultUser = AppUser(
                    id: "bamp",
                    username: "Bamp",
                    email: "bamp@example.com"
                )
                
                try await db.collection("users").document("bamp").setData(defaultUser.dictionary)
                await MainActor.run {
                    self.currentUser = defaultUser
                }
            } else {
                // Load existing user
                if let user = AppUser.fromDictionary(userDoc.data() ?? [:]) {
                    await MainActor.run {
                        self.currentUser = user
                    }
                }
            }
        } catch {
            print("Error creating/loading default user: \(error)")
        }
    }
    
    func updateUser(_ user: AppUser) async throws {
        try await db.collection("users").document(user.id).setData(user.dictionary)
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    func signUp(username: String, email: String, password: String) async throws {
        let user = AppUser(
            id: UUID().uuidString,
            username: username,
            email: email,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await db.collection("users").document(user.id).setData(user.dictionary)
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    func signIn(email: String, password: String) {
        // For testing, create a default user
        let user = AppUser(
            id: "bamp",
            username: "bamp",
            email: email,
            createdAt: Date(),
            updatedAt: Date()
        )
        self.currentUser = user
        self.isAuthenticated = true
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
