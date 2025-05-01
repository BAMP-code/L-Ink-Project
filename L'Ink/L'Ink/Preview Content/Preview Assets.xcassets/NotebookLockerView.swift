import SwiftUI

struct NotebookLockerView: View {
    @State private var lockedNotebooks: [LockedNotebook] = []
    @State private var showingNewLockedNotebook = false
    @State private var searchText = ""
    
    var filteredNotebooks: [LockedNotebook] {
        if searchText.isEmpty {
            return lockedNotebooks
        } else {
            return lockedNotebooks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding()
                
                if filteredNotebooks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No locked notebooks")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Create a locked notebook to keep your private notes secure")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredNotebooks) { notebook in
                            LockedNotebookRow(notebook: notebook)
                        }
                    }
                }
            }
            .navigationTitle("Notebook Locker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewLockedNotebook = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewLockedNotebook) {
                NewLockedNotebookView()
            }
        }
    }
}

struct LockedNotebookRow: View {
    let notebook: LockedNotebook
    @State private var showingUnlockAlert = false
    @State private var password = ""
    
    var body: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(notebook.title)
                    .font(.headline)
                
                Text("Last modified: \(notebook.lastModified, style: .date)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { showingUnlockAlert = true }) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .alert("Unlock Notebook", isPresented: $showingUnlockAlert) {
            SecureField("Password", text: $password)
            Button("Cancel", role: .cancel) { }
            Button("Unlock") {
                // Verify password and unlock notebook
            }
        }
    }
}

struct NewLockedNotebookView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notebook Details")) {
                    TextField("Title", text: $title)
                }
                
                Section(header: Text("Security")) {
                    SecureField("Password", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)
                }
                
                if !password.isEmpty && !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords do not match")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("New Locked Notebook")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    // Create locked notebook
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.isEmpty || !passwordsMatch)
            )
        }
    }
}

struct LockedNotebook: Identifiable {
    let id = UUID()
    let title: String
    let lastModified: Date
} 