import SwiftUI
import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?
    @Published var headerImage: UIImage?
    @Published var profileImage: UIImage?
    
    private let db = Firestore.firestore()
    
    init() {
        listenToAuthState()
    }
    
    private func listenToAuthState() {
        let _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                self.fetchUser(uid: user.uid)
            } else {
                self.currentUser = nil
                self.isAuthenticated = false
                self.headerImage = nil
                self.profileImage = nil
            }
        }
    }
    
    private func loadImages() {
        print("🔄 Starting to load images in AuthViewModel...")
        
        Task {
            if let headerURL = currentUser?.headerImageURL {
                print("📸 Found header URL: \(headerURL)")
                if let url = URL(string: headerURL) {
                    do {
                        print("📥 Downloading header image...")
                        let (data, response) = try await URLSession.shared.data(from: url)
                        if let httpResponse = response as? HTTPURLResponse {
                            print("📡 Header image response status: \(httpResponse.statusCode)")
                        }
                        if let image = UIImage(data: data) {
                            print("✅ Header image loaded successfully")
                            await MainActor.run {
                                self.headerImage = image
                            }
                        } else {
                            print("❌ Failed to create header image from data")
                        }
                    } catch {
                        print("❌ Error loading header image: \(error)")
                    }
                }
            }
            
            if let profileURL = currentUser?.profileImageURL {
                print("📸 Found profile URL: \(profileURL)")
                if let url = URL(string: profileURL) {
                    do {
                        print("📥 Downloading profile image...")
                        let (data, response) = try await URLSession.shared.data(from: url)
                        if let httpResponse = response as? HTTPURLResponse {
                            print("📡 Profile image response status: \(httpResponse.statusCode)")
                        }
                        if let image = UIImage(data: data) {
                            print("✅ Profile image loaded successfully")
                            await MainActor.run {
                                self.profileImage = image
                            }
                        } else {
                            print("❌ Failed to create profile image from data")
                        }
                    } catch {
                        print("❌ Error loading profile image: \(error)")
                    }
                }
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
                profileImageURL: "https://firebasestorage.googleapis.com/v0/b/l-ink-56601.firebasestorage.app/o/users%2Fdev-placeholder-user%2Fprofile.jpg?alt=media",
                headerImageURL: "https://firebasestorage.googleapis.com/v0/b/l-ink-56601.firebasestorage.app/o/users%2Fdev-placeholder-user%2Fheader.jpg?alt=media",
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
                    print("✅ User data loaded successfully")
                    print("📸 Profile URL: \(user.profileImageURL ?? "none")")
                    print("🖼️ Header URL: \(user.headerImageURL ?? "none")")
                    
                    // Load images immediately after user data is fetched
                    self.loadImages()
                }
            } else {
                print("❌ Error fetching user: \(error?.localizedDescription ?? "No data")")
                if let error = error {
                    print("🔍 Detailed error: \(error)")
                }
            }
        }
    }
}
