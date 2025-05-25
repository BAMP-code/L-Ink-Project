import SwiftUI
import FirebaseStorage

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var headerImage: UIImage?
    @State private var showingImagePicker = false
    @State private var profileImage: UIImage?
    @State private var showingProfileImagePicker = false
    @State private var isUploading = false
    
    // Sample data
    let savedNotebooks: [String: [String]] = [
        "Travel": ["Japan 2023", "Italy Adventure"],
        "Recipes": ["Vegan Delights", "Quick Meals"]
    ]
    let collections: [String] = ["Favorites", "Work", "Personal"]
    let likedNotebooks: [String] = ["Art Portfolio 2024", "Math Notes"]
    let featuredScrapbooks: [String] = ["My Best Scrapbook"]
    let badges: [String] = ["Creative Star", "Consistent Contributor", "Community Helper"]
    let scrapbookStats = (
        pages: 123
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header and profile image section
                    ZStack(alignment: .bottomLeading) {
                        // Header image
                        if let headerImage = headerImage {
                            Image(uiImage: headerImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipped()
                                .cornerRadius(16)
                                .padding(.horizontal)
                        } else if let headerURL = authViewModel.currentUser?.headerImageURL {
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
                        
                        // Header image picker button
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                Button(action: { showingImagePicker = true }) {
                                    Image(systemName: "camera.fill")
                                        .padding(8)
                                        .background(Color.white.opacity(0.8))
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                }
                                .padding(.trailing, 32)
                                .padding(.bottom, 16)
                            }
                        }
                        
                        // Profile image (overlapping bottom left)
                        ZStack(alignment: .bottomTrailing) {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                    .shadow(radius: 4)
                                    .offset(x: 32, y: 50)
                            } else if let profileURL = authViewModel.currentUser?.profileImageURL {
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
                            
                            Button(action: { showingProfileImagePicker = true }) {
                                Image(systemName: "camera.fill")
                                    .padding(6)
                                    .background(Color.white.opacity(0.8))
                                    .clipShape(Circle())
                                    .offset(x: 32, y: 54)
                            }
                        }
                    }
                    .sheet(isPresented: $showingImagePicker) {
                        ImagePicker(image: $headerImage)
                            .onChange(of: headerImage) { newImage in
                                if let image = newImage {
                                    uploadHeaderImage(image)
                                }
                            }
                    }
                    .sheet(isPresented: $showingProfileImagePicker) {
                        ImagePicker(image: $profileImage)
                            .onChange(of: profileImage) { newImage in
                                if let image = newImage {
                                    uploadProfileImage(image)
                                }
                            }
                    }

                    // Add vertical spacing below the header/profile image
                    Spacer().frame(height: 60)

                    // Profile Info and rest of the content
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
                            Text("Pages Created: \(scrapbookStats.pages)")
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

                    // Saved Notebooks by Tag/Collection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saved Notebooks")
                            .font(.headline)
                        ForEach(savedNotebooks.keys.sorted(), id: \.self) { tag in
                            VStack(alignment: .leading) {
                                Text(tag)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(savedNotebooks[tag]!, id: \.self) { notebook in
                                            NotebookCardView(title: notebook)
                                        }
                                    }
                                }
                            }
                        }
                        // Collections
                        Text("Collections")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(collections, id: \.self) { collection in
                                    NotebookCardView(title: collection)
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
    
    private func uploadHeaderImage(_ image: UIImage) {
        guard let userId = authViewModel.currentUser?.id else { return }
        isUploading = true
        
        Task {
            do {
                let path = "users/\(userId)/header.jpg"
                let imageURL = try await StorageService.shared.uploadImage(image, path: path)
                
                // Update user profile in Firestore
                var updatedUser = authViewModel.currentUser
                updatedUser?.headerImageURL = imageURL
                if let user = updatedUser {
                    try await authViewModel.updateUser(user)
                }
                
                isUploading = false
            } catch {
                print("Error uploading header image: \(error)")
                isUploading = false
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) {
        guard let userId = authViewModel.currentUser?.id else { return }
        isUploading = true
        
        Task {
            do {
                let path = "users/\(userId)/profile.jpg"
                let imageURL = try await StorageService.shared.uploadImage(image, path: path)
                
                // Update user profile in Firestore
                var updatedUser = authViewModel.currentUser
                updatedUser?.profileImageURL = imageURL
                if let user = updatedUser {
                    try await authViewModel.updateUser(user)
                }
                
                isUploading = false
            } catch {
                print("Error uploading profile image: \(error)")
                isUploading = false
            }
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
        }
    }
}
