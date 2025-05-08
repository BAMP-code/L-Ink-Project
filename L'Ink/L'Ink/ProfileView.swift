import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var selectedTab = 0
    
    // Sample data - replace with your actual notebook data
    let notebooks = [
        "Notebook 1", "Notebook 2", "Notebook 3",
        "Notebook 4", "Notebook 5", "Notebook 6"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    HStack(spacing: 20) {
                        // Profile Image
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)
                        
                        // Stats
                        HStack(spacing: 30) {
                            VStack {
                                Text("\(notebooks.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("Notebooks")
                                    .font(.caption)
                            }
                            
                            VStack {
                                Text("45")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("Notes")
                                    .font(.caption)
                            }
                            
                            VStack {
                                Text("8")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("Shared")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Bio Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authViewModel.currentUser?.username ?? "Username")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Bio goes here")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
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
                    .padding(.top, 8)
                    
                    // Tabs
                    HStack {
                        Spacer()
                        Button(action: { selectedTab = 0 }) {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(selectedTab == 0 ? .primary : .gray)
                        }
                        Spacer()
                        Button(action: { selectedTab = 1 }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(selectedTab == 1 ? .primary : .gray)
                        }
                        Spacer()
                        Button(action: { selectedTab = 2 }) {
                            Image(systemName: "person.2")
                                .foregroundColor(selectedTab == 2 ? .primary : .gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.2)),
                        alignment: .top
                    )
                    
                    // Notebooks Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 2) {
                        ForEach(notebooks, id: \.self) { notebook in
                            NotebookGridItem(notebook: notebook)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

struct NotebookGridItem: View {
    let notebook: String
    
    var body: some View {
        VStack {
            Image(systemName: "book.closed.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(.blue)
                .padding()
                .background(Color.gray.opacity(0.1))
        }
        .aspectRatio(1, contentMode: .fit)
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
