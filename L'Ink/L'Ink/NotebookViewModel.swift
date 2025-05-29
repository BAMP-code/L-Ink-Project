import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class NotebookViewModel: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private let notebooksCollection = "notebooks"
    private let entriesCollection = "entries"
    
    var currentUserid: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Notebook Operations
    
    func fetchNotebooks() {
        guard !currentUserid.isEmpty else {
            print("Current user ID is empty. Cannot fetch notebooks.")
            // Optionally clear existing notebooks if needed
            self.notebooks = []
            return
        }
        
        db.collection("notebooks")
            .whereField("ownerId", isEqualTo: currentUserid) // Filter by ownerId
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching notebooks: \(error?.localizedDescription ?? "Unknown error")")
                    // If no documents and no error, it means no notebooks for this user
                    if error == nil {
                        self?.notebooks = [] // Clear notebooks if none found for user
                        self?.createDefaultNotebook() // Create default if none exist
                    }
                    return
                }
                
                self?.notebooks = documents.compactMap { document in
                    Notebook.fromDictionary(document.data())
                }
                
                // Reset pinned status for all notebooks
                self?.resetPinnedStatus()
                
                // If no notebooks exist for the current user after fetching, create a default one
                if self?.notebooks.isEmpty == true {
                    self?.createDefaultNotebook()
                }
            }
    }
    
    private func resetPinnedStatus() {
        for notebook in notebooks where notebook.isPinned {
            var updatedNotebook = notebook
            updatedNotebook.isPinned = false
            updateNotebook(updatedNotebook)
        }
    }
    
    private func createDefaultNotebook() {
        guard !currentUserid.isEmpty else {
            print("Current user ID is empty. Cannot create default notebook.")
            return
        }
        let coverPage = Page(
            id: UUID().uuidString,
            content: "Welcome to your notebook!",
            type: .cover,
            createdAt: Date(),
            updatedAt: Date(),
            order: 0
        )
        let defaultNotebook = Notebook(
            title: "My First Notebook",
            description: "Welcome to L'Ink! This is your first notebook.",
            ownerId: currentUserid, // Use currentUserid
            isPublic: false,
            isPinned: false,
            pages: [coverPage],
            lastViewedPageIndex: 0,
            coverImage: "Blue"
        )
        db.collection("notebooks").document(defaultNotebook.id).setData(defaultNotebook.dictionary) { error in
            if let error = error {
                print("Error creating default notebook: \(error.localizedDescription)")
            }
        }
    }
    
    func createNotebook(title: String, isPublic: Bool, description: String? = nil, cover: String = "Blue") {
        guard !currentUserid.isEmpty else {
            print("Current user ID is empty. Cannot create notebook.")
            return
        }
        let coverPage = Page(
            id: UUID().uuidString,
            content: "Welcome to your notebook!",
            type: .cover,
            createdAt: Date(),
            updatedAt: Date(),
            order: 0
        )
        let notebook = Notebook(
            title: title,
            description: description,
            ownerId: currentUserid, // Use currentUserid
            isPublic: isPublic,
            isPinned: false,
            pages: [coverPage],
            lastViewedPageIndex: 0,
            coverImage: cover
        )
        db.collection("notebooks").document(notebook.id).setData(notebook.dictionary) { error in
            if let error = error {
                print("Error creating notebook: \(error.localizedDescription)")
            }
        }
    }
    
    func updateNotebook(_ notebook: Notebook) {
        print("Updating notebook with ID: \(notebook.id)")
        print("Notebook data: \(notebook.dictionary)")
        db.collection("notebooks").document(notebook.id).updateData(notebook.dictionary) { error in
            if let error = error {
                print("Error updating notebook: \(error.localizedDescription)")
                print("Error details: \(error)")
            } else {
                print("Successfully updated notebook")
            }
        }
    }
    
    func deleteNotebook(_ notebook: Notebook) {
        db.collection("notebooks").document(notebook.id).delete() { error in
            if let error = error {
                print("Error deleting notebook: \(error.localizedDescription)")
            }
        }
    }
    
    func togglePin(_ notebook: Notebook) {
        var updatedNotebook = notebook
        updatedNotebook.isPinned.toggle()
        updateNotebook(updatedNotebook)
    }
    
    func toggleFavorite(_ notebook: Notebook) {
        var updatedNotebook = notebook
        updatedNotebook.isFavorite.toggle()
        updateNotebook(updatedNotebook)
    }
    
    // Page Management Functions
    func addPage(to notebook: Notebook, type: PageType) {
        var updatedNotebook = notebook
        let newPage = Page(
            id: UUID().uuidString,
            content: "",
            type: type,
            createdAt: Date(),
            updatedAt: Date(),
            order: updatedNotebook.pages.count
        )
        updatedNotebook.pages.append(newPage)
        updatedNotebook.updatedAt = Date()
        updateNotebook(updatedNotebook)
    }
    
    func updatePage(in notebook: Notebook, pageId: String, content: String) {
        var updatedNotebook = notebook
        if let index = updatedNotebook.pages.firstIndex(where: { $0.id == pageId }) {
            updatedNotebook.pages[index].content = content
            updatedNotebook.pages[index].updatedAt = Date()
            updatedNotebook.updatedAt = Date()
            updateNotebook(updatedNotebook)
        }
    }
    
    func deletePage(from notebook: Notebook, pageId: String) {
        var updatedNotebook = notebook
        updatedNotebook.pages.removeAll { $0.id == pageId }
        // Reorder remaining pages
        for (index, _) in updatedNotebook.pages.enumerated() {
            updatedNotebook.pages[index].order = index
        }
        updatedNotebook.updatedAt = Date()
        updateNotebook(updatedNotebook)
    }
    
    func reorderPages(in notebook: Notebook, from source: IndexSet, to destination: Int) {
        var updatedNotebook = notebook
        updatedNotebook.pages.move(fromOffsets: source, toOffset: destination)
        // Update order for all pages
        for (index, _) in updatedNotebook.pages.enumerated() {
            updatedNotebook.pages[index].order = index
        }
        updatedNotebook.updatedAt = Date()
        updateNotebook(updatedNotebook)
    }
    
    // MARK: - Entry Operations
    
    func createEntry(notebookId: String, title: String, content: String) async throws {
        let entry = Entry(
            id: UUID().uuidString,
            notebookId: notebookId,
            title: title,
            content: content,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await db.collection(entriesCollection).document(entry.id).setData([
            "notebook_id": entry.notebookId,
            "title": entry.title,
            "content": entry.content,
            "created_at": entry.createdAt,
            "updated_at": entry.updatedAt
        ])
    }
    
    func fetchEntries(for notebookId: String) async throws -> [Entry] {
        let snapshot = try await db.collection(entriesCollection)
            .whereField("notebook_id", isEqualTo: notebookId)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document -> Entry? in
            let data = document.data()
            return Entry(
                id: document.documentID,
                notebookId: data["notebook_id"] as? String ?? "",
                title: data["title"] as? String ?? "",
                content: data["content"] as? String ?? "",
                createdAt: (data["created_at"] as? Timestamp)?.dateValue() ?? Date(),
                updatedAt: (data["updated_at"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }
    
    func updateEntry(_ entry: Entry) async throws {
        try await db.collection(entriesCollection).document(entry.id).updateData([
            "title": entry.title,
            "content": entry.content,
            "updated_at": Date()
        ])
    }
    
    func deleteEntry(_ entry: Entry) async throws {
        try await db.collection(entriesCollection).document(entry.id).delete()
    }
}

// MARK: - Models

struct Entry: Identifiable {
    let id: String
    let notebookId: String
    let title: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
}
