import SwiftUI
import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    init() {
        listenToAuthState()
    }
    
    private func listenToAuthState() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                self.fetchUser(uid: user.uid)
            } else {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    func signUp(username: String, email: String, password: String) async throws {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = authResult.user.uid
        let newUser = AppUser(
            id: uid,
            username: username,
            email: email,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.collection("users").document(uid).setData(newUser.dictionary)
        await MainActor.run {
            self.currentUser = newUser
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) {
        #if DEBUG
        if email.isEmpty && password.isEmpty {
            let testUser = AppUser(
                id: "dev-placeholder-user",
                username: "TestUser",
                email: "test@example.com",
                createdAt: Date(),
                updatedAt: Date()
            )
            self.currentUser = testUser
            self.isAuthenticated = true
            print("Signed in with placeholder user (DEBUG)")
            return
        }
        #endif

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            guard let uid = result?.user.uid else { return }
            self.fetchUser(uid: uid)
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
        } catch {
            self.errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
    
    func updateUser(_ user: AppUser) async throws {
        try await db.collection("users").document(user.id).setData(user.dictionary)
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    private func fetchUser(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let data = snapshot?.data(),
               let user = AppUser.fromDictionary(data) {
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
            } else {
                print("Error fetching user: \(error?.localizedDescription ?? "No data")")
            }
        }
    }
}
