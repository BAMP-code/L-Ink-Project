import SwiftUI
import FirebaseStorage
import PhotosUI
import Combine

extension Notification.Name {
    static let userDataUpdated = Notification.Name("userDataUpdated")
}

@MainActor
class ProfileImageViewModel: ObservableObject {
    @Published var headerImage: UIImage?
    @Published var profileImage: UIImage?
    @Published var isUploading = false
    private var authViewModel: AuthViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        setupNotificationObserver()
        loadImages()
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: .userDataUpdated)
            .sink { [weak self] _ in
                self?.loadImages()
            }
            .store(in: &cancellables)
    }
    
    func updateAuthViewModel(_ newAuthViewModel: AuthViewModel) {
        self.authViewModel = newAuthViewModel
        loadImages()
    }
    
    private func loadImages() {
        print("🔄 Starting to load images...")
        
        Task {
            if let headerURL = authViewModel.currentUser?.headerImageURL {
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
                } else {
                    print("❌ Invalid header URL: \(headerURL)")
                }
            } else {
                print("ℹ️ No header URL found")
            }
            
            if let profileURL = authViewModel.currentUser?.profileImageURL {
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
                } else {
                    print("❌ Invalid profile URL: \(profileURL)")
                }
            } else {
                print("ℹ️ No profile URL found")
            }
        }
    }
    
    func handleHeaderImageSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        print("Header image selected")
        headerImage = image
        await uploadHeaderImage(image)
    }
    
    func handleProfileImageSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        print("📸 Profile image selected")
        profileImage = image
        await uploadProfileImage(image)
    }
    
    private func uploadHeaderImage(_ image: UIImage) async {
        guard let userId = authViewModel.currentUser?.id else { 
            print("Error: No user ID found")
            return 
        }
        print("📸 Starting header image upload for user: \(userId)")
        isUploading = true
        
        do {
            let path = "users/\(userId)/header.jpg"
            print("📤 Uploading header image to path: \(path)")
            let imageURL = try await StorageService.shared.uploadImage(image, path: path)
            print("✅ Header image uploaded successfully. URL: \(imageURL)")
            
            var updatedUser = authViewModel.currentUser
            updatedUser?.headerImageURL = imageURL
            updatedUser?.updatedAt = Date()
            if let user = updatedUser {
                try await authViewModel.updateUser(user)
                print("✅ User updated successfully with header image")
            }
        } catch {
            print("❌ Error uploading header image: \(error)")
        }
        isUploading = false
    }
    
    private func uploadProfileImage(_ image: UIImage) async {
        guard let userId = authViewModel.currentUser?.id else { 
            print("❌ Error: No user ID found")
            return 
        }
        print("📸 Starting profile image upload for user: \(userId)")
        isUploading = true
        
        do {
            let path = "users/\(userId)/profile.jpg"
            print("📤 Uploading profile image to path: \(path)")
            let imageURL = try await StorageService.shared.uploadImage(image, path: path)
            print("✅ Profile image uploaded successfully. URL: \(imageURL)")
            
            var updatedUser = authViewModel.currentUser
            updatedUser?.profileImageURL = imageURL
            updatedUser?.updatedAt = Date()
            if let user = updatedUser {
                try await authViewModel.updateUser(user)
                print("✅ User updated successfully with profile image")
            }
        } catch {
            print("❌ Error uploading profile image: \(error)")
        }
        isUploading = false
    }
}

// MARK: - Header Image View
struct HeaderImageView: View {
    let headerImage: UIImage?
    let headerURL: String?
    
    var body: some View {
        Group {
            if let headerImage = headerImage {
                Image(uiImage: headerImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(16)
                    .padding(.horizontal)
            } else if let headerURL = headerURL {
                AsyncImage(url: URL(string: headerURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image("Logo")
                        .resizable()
                        .scaledToFill()
                }
                .frame(height: 160)
                .clipped()
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                Image("Logo")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(16)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Profile Image View
struct ProfileImageView: View {
    let profileImage: UIImage?
    let profileURL: String?
    
    var body: some View {
        Group {
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 4)
                    .offset(x: 32, y: 50)
            } else if let profileURL = profileURL {
                AsyncImage(url: URL(string: profileURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(radius: 4)
                .offset(x: 32, y: 50)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 4)
                    .offset(x: 32, y: 50)
            }
        }
    }
}

// MARK: - Profile Header Section
struct ProfileHeaderSection: View {
    @Binding var selectedHeaderItem: PhotosPickerItem?
    @Binding var selectedProfileItem: PhotosPickerItem?
    let headerImage: UIImage?
    let headerURL: String?
    let profileImage: UIImage?
    let profileURL: String?
    let onHeaderImageSelected: (PhotosPickerItem) async -> Void
    let onProfileImageSelected: (PhotosPickerItem) async -> Void
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HeaderImageView(headerImage: headerImage, headerURL: headerURL)
            
            // Header image picker button
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    PhotosPicker(selection: $selectedHeaderItem,
                               matching: .images,
                               photoLibrary: .shared()) {
                        Image(systemName: "camera.fill")
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .onChange(of: selectedHeaderItem) { _, newValue in
                        if let item = newValue {
                            Task {
                                await onHeaderImageSelected(item)
                            }
                        }
                    }
                    .padding(.trailing, 32)
                    .padding(.bottom, 16)
                }
            }
            
            // Profile image
            ZStack(alignment: .bottomTrailing) {
                ProfileImageView(profileImage: profileImage, profileURL: profileURL)
                
                PhotosPicker(selection: $selectedProfileItem,
                           matching: .images,
                           photoLibrary: .shared()) {
                    Image(systemName: "camera.fill")
                        .padding(6)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                }
                .onChange(of: selectedProfileItem) { _, newValue in
                    if let item = newValue {
                        Task {
                            await onProfileImageSelected(item)
                        }
                    }
                }
                .offset(x: 32, y: 54)
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var selectedHeaderItem: PhotosPickerItem?
    @State private var selectedProfileItem: PhotosPickerItem?
    @State private var isUploading = false
    
    // Sample data
    let likedNotebooks: [String] = ["Art Portfolio 2024", "Math Notes"]
    let featuredScrapbooks: [String] = ["My Best Scrapbook"]
    let badges: [String] = ["Creative Star", "Consistent Contributor", "Community Helper"]
    let scrapbookPages = 123
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ProfileHeaderSection(
                        selectedHeaderItem: $selectedHeaderItem,
                        selectedProfileItem: $selectedProfileItem,
                        headerImage: authViewModel.headerImage,
                        headerURL: authViewModel.currentUser?.headerImageURL,
                        profileImage: authViewModel.profileImage,
                        profileURL: authViewModel.currentUser?.profileImageURL,
                        onHeaderImageSelected: handleHeaderImageSelection,
                        onProfileImageSelected: handleProfileImageSelection
                    )
                    
                    // Add vertical spacing
                    Spacer().frame(height: 60)
                    
                    // Profile Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authViewModel.currentUser?.username ?? "Username")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Bio goes here")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 10) {
                        Button(action: { showingEditProfile = true }) {
                            Text("Edit Profile")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                                .frame(width: 30)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Scrapbook Stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scrapbook Stats")
                            .font(.headline)
                        HStack {
                            Text("Pages Created: \(scrapbookPages)")
                            Spacer()
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal)

                    // Featured Scrapbooks
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Featured Scrapbooks")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(featuredScrapbooks, id: \.self) { scrapbook in
                                    VStack {
                                        Image("Logo")
                                            .resizable()
                                            .frame(width: 100, height: 100)
                                            .cornerRadius(12)
                                        Text(scrapbook)
                                            .font(.caption)
                                    }
                                    .padding(4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Liked Notebooks
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Liked Notebooks")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(likedNotebooks, id: \.self) { notebook in
                                    NotebookCardView(title: notebook)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Badges/Achievements
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Badges & Achievements")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(badges, id: \.self) { badge in
                                    VStack {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .frame(width: 40, height: 40)
                                        Text(badge)
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .overlay {
                if isUploading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
    
    private func handleHeaderImageSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        print("Header image selected")
        isUploading = true
        await uploadHeaderImage(image)
        isUploading = false
    }
    
    private func handleProfileImageSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        print("📸 Profile image selected")
        isUploading = true
        await uploadProfileImage(image)
        isUploading = false
    }
    
    private func uploadHeaderImage(_ image: UIImage) async {
        guard let userId = authViewModel.currentUser?.id else { 
            print("Error: No user ID found")
            return 
        }
        print("📸 Starting header image upload for user: \(userId)")
        
        do {
            let path = "users/\(userId)/header.jpg"
            print("📤 Uploading header image to path: \(path)")
            let imageURL = try await StorageService.shared.uploadImage(image, path: path)
            print("✅ Header image uploaded successfully. URL: \(imageURL)")
            
            var updatedUser = authViewModel.currentUser
            updatedUser?.headerImageURL = imageURL
            updatedUser?.updatedAt = Date()
            if let user = updatedUser {
                try await authViewModel.updateUser(user)
                print("✅ User updated successfully with header image")
            }
        } catch {
            print("❌ Error uploading header image: \(error)")
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) async {
        guard let userId = authViewModel.currentUser?.id else { 
            print("❌ Error: No user ID found")
            return 
        }
        print("📸 Starting profile image upload for user: \(userId)")
        
        do {
            let path = "users/\(userId)/profile.jpg"
            print("📤 Uploading profile image to path: \(path)")
            let imageURL = try await StorageService.shared.uploadImage(image, path: path)
            print("✅ Profile image uploaded successfully. URL: \(imageURL)")
            
            var updatedUser = authViewModel.currentUser
            updatedUser?.profileImageURL = imageURL
            updatedUser?.updatedAt = Date()
            if let user = updatedUser {
                try await authViewModel.updateUser(user)
                print("✅ User updated successfully with profile image")
            }
        } catch {
            print("❌ Error uploading profile image: \(error)")
        }
    }
}

struct NotebookCardView: View {
    let title: String
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
        .padding(4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var username: String = ""
    @State private var bio: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Username", text: $username)
                    TextField("Bio", text: $bio)
                }
                
                Section(header: Text("Account")) {
                    Button(action: {
                        // Add change password functionality
                    }) {
                        Text("Change Password")
                    }
                    
                    Button(action: {
                        // Add delete account functionality
                    }) {
                        Text("Delete Account")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    // Save profile changes
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                // Initialize with current user data
                username = authViewModel.currentUser?.username ?? ""
                bio = "" // Add bio to your user model if needed
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                }
                
                Section(header: Text("Privacy")) {
                    NavigationLink(destination: Text("Privacy Settings")) {
                        Text("Privacy Settings")
                    }
                    
                    NavigationLink(destination: Text("Blocked Users")) {
                        Text("Blocked Users")
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    Link("Terms of Service", destination: URL(string: "https://yourwebsite.com/terms")!)
                    Link("Privacy Policy", destination: URL(string: "https://yourwebsite.com/privacy")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
