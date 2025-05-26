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
        // Initialize without automatic authentication
        isAuthenticated = false
        currentUser = nil
    }
    
    private func createDefaultUser() async {
        do {
            let userDoc = try await db.collection("users").document("bamp").getDocument()
            
            if !userDoc.exists {
                // Create default user
                let defaultUser = AppUser(
                    id: "bamp",
                    username: "Bamp",
                    email: "bamp@example.com",
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                try await db.collection("users").document("bamp").setData(defaultUser.dictionary)
                await MainActor.run {
                    self.currentUser = defaultUser
                    self.isAuthenticated = true
                }
            } else {
                // Load existing user
                if let user = AppUser.fromDictionary(userDoc.data() ?? [:]) {
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
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
        
        // Only authenticate if email and password are not empty
        if !email.isEmpty && !password.isEmpty {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
    }
}

struct User {
    let id: String
    let email: String
    let username: String
} 
