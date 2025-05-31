//
//  NotebookFeedView.swift
//  L'Ink
//
//  Created by Daniela on 4/28/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PencilKit

class PublicNotebook: Identifiable, ObservableObject {
    let id = UUID()
    let firestoreId: String
    @Published var notebook: Notebook  // Changed from let to @Published var
    @Published var author: String
    @Published var authorImage: String
    @Published var likes: Int
    @Published var comments: [NotebookComment]
    @Published var isLiked: Bool = false
    @Published var isSaved: Bool = false
    @Published var feedDescription: String = ""
    
    // Ranking score properties
    @Published var viewCount: Int = 0
    @Published var saveCount: Int = 0
    @Published var shareCount: Int = 0
    @Published var timeSpentSeconds: Int = 0
    @Published var rankingScore: Double = 0.0
    
    init(firestoreId: String, notebook: Notebook, author: String, authorImage: String, likes: Int, comments: [NotebookComment], isLiked: Bool, isSaved: Bool, feedDescription: String, viewCount: Int = 0, saveCount: Int = 0, shareCount: Int = 0, timeSpentSeconds: Int = 0, rankingScore: Double = 0.0) {
        self.firestoreId = firestoreId
        self.notebook = notebook
        self.author = author
        self.authorImage = authorImage
        self.likes = likes
        self.comments = comments
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.feedDescription = feedDescription
        self.viewCount = viewCount
        self.saveCount = saveCount
        self.shareCount = shareCount
        self.timeSpentSeconds = timeSpentSeconds
        self.rankingScore = rankingScore
    }
}

struct NotebookComment: Identifiable {
    let id = UUID()
    let username: String
    let text: String
    let timestamp: Date
}

class FeedViewModel: ObservableObject {
    @Published var notebooks: [PublicNotebook] = []
    @Published var searchText: String = ""
    @Published var userProfileImages: [String: String] = [:] // userId: profileImageURL
    @Published var userNotebooks: [PublicNotebook] = []
    private let notebookViewModel = NotebookViewModel()
    
    // User interaction history
    private var userInteractionHistory: [String: [Date]] = [:] // notebookId: [interaction timestamps]
    private var userPreferences: Set<String> = [] // tags user has shown interest in
    private let recommendationEngine = RecommendationEngine()
    private let currentUserId: String
    private var likedNotebooks: Set<String> = [] // Cache of liked notebook IDs
    
    private let db = Firestore.firestore()
    
    init() {
        // Get the current user ID from Firebase Auth
        if let user = Auth.auth().currentUser {
            self.currentUserId = user.uid
            print("Current user ID: \(self.currentUserId)") // Debug log
            fetchLikedNotebooks()
            fetchUserNotebooks() // Fetch user notebooks on init
        } else {
            self.currentUserId = ""
            print("No authenticated user found")
        }
        fetchNotebooks()
        calculateRankingScores()
    }
    
    func loadMockData() {
        // This is now just a fallback in case of errors
        notebooks = []
    }
    
    private func fetchLikedNotebooks() {
        let userRef = db.collection("users").document(currentUserId)
        userRef.getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let userData = snapshot?.data() else {
                print("Error fetching user data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Get the array of liked notebook IDs, create if doesn't exist
            let likedIds = userData["likedNotebooks"] as? [String] ?? []
            self.likedNotebooks = Set(likedIds)
            
            // Update isLiked state for all notebooks
            for (index, notebook) in self.notebooks.enumerated() {
                self.notebooks[index].isLiked = self.likedNotebooks.contains(notebook.firestoreId)
            }
        }
    }
    
    private func fetchUserProfileImage(userId: String) {
        // Skip if we already have the image URL
        guard userProfileImages[userId] == nil else { return }
        
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let userData = snapshot?.data(),
                  let profileImageURL = userData["profileImageURL"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                self.userProfileImages[userId] = profileImageURL
            }
        }
    }
    
    func fetchNotebooks() {
        // Remove the snapshot listener and use get() instead
        db.collection("notebooks")
            .whereField("isPublic", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching notebooks: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.processNotebookDocuments(documents)
            }
    }
    
    private func processNotebookDocuments(_ documents: [QueryDocumentSnapshot]) {
        self.notebooks = documents.compactMap { document in
            let data = document.data()
            
            // Create notebook from Firestore data
            let notebook = Notebook(
                id: document.documentID,
                title: data["title"] as? String ?? "",
                description: data["description"] as? String,
                ownerId: data["ownerId"] as? String ?? "",
                isPublic: data["isPublic"] as? Bool ?? false,
                isPinned: data["isPinned"] as? Bool ?? false,
                isFavorite: data["isFavorite"] as? Bool ?? false,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                pages: [], // We'll populate this below
                lastViewedPageIndex: data["lastViewedPageIndex"] as? Int ?? 0,
                coverImage: data["coverImage"] as? String ?? "Blue"
            )
            
            // Extract and convert pages array
            let pagesData = data["pages"] as? [[String: Any]] ?? []
            let pages = pagesData.compactMap { pageData -> Page? in
                guard let id = pageData["id"] as? String,
                      let content = pageData["content"] as? String,
                      let typeString = pageData["type"] as? String,
                      let type = PageType(rawValue: typeString),
                      let order = pageData["order"] as? Int,
                      let createdAt = (pageData["createdAt"] as? Timestamp)?.dateValue(),
                      let updatedAt = (pageData["updatedAt"] as? Timestamp)?.dateValue()
                else {
                    return nil
                }
                
                // Decode canvas elements
                let drawingData = pageData["drawingData"] as? Data
                
                let textBoxes = (pageData["textBoxes"] as? [[String: Any]])?.compactMap { boxDict -> CanvasTextBoxModel? in
                    guard let idString = boxDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let text = boxDict["text"] as? String,
                          let positionDict = boxDict["position"] as? [String: CGFloat],
                          let x = positionDict["x"],
                          let y = positionDict["y"] else {
                        return nil
                    }
                    
                    // Get size information
                    var size: CGSizeCodable? = nil
                    if let sizeDict = boxDict["size"] as? [String: CGFloat],
                       let width = sizeDict["width"],
                       let height = sizeDict["height"] {
                        size = CGSizeCodable(CGSize(width: width, height: height))
                    }
                    
                    return CanvasTextBoxModel(
                        id: id,
                        text: text,
                        position: CGPointCodable(CGPoint(x: x, y: y)),
                        size: size
                    )
                }
                
                let images = (pageData["images"] as? [[String: Any]])?.compactMap { imgDict -> CanvasImageModel? in
                    guard let idString = imgDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let imageUrl = imgDict["imageUrl"] as? String,
                          let positionDict = imgDict["position"] as? [String: CGFloat],
                          let x = positionDict["x"],
                          let y = positionDict["y"] else {
                        return nil
                    }
                    
                    // Get size information
                    var size: CGSizeCodable? = nil
                    if let sizeDict = imgDict["size"] as? [String: CGFloat],
                       let width = sizeDict["width"],
                       let height = sizeDict["height"] {
                        size = CGSizeCodable(CGSize(width: width, height: height))
                    }
                    
                    return CanvasImageModel(
                        id: id,
                        imageData: nil,
                        imageUrl: imageUrl,
                        position: CGPointCodable(CGPoint(x: x, y: y)),
                        size: size
                    )
                }
                
                return Page(
                    id: id,
                    content: content,
                    type: type,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    order: order,
                    drawingData: drawingData,
                    textBoxes: textBoxes,
                    images: images
                )
            }
            
            // Sort pages by order
            let sortedPages = pages.sorted { $0.order < $1.order }
            
            // Extract likes array
            let likes = data["likes"] as? [String] ?? []
            
            // Extract and convert comments
            let commentsData = data["comments"] as? [[String: Any]] ?? []
            let comments = commentsData.compactMap { commentData -> NotebookComment? in
                guard let username = commentData["username"] as? String,
                      let text = commentData["text"] as? String,
                      let timestamp = (commentData["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                return NotebookComment(username: username, text: text, timestamp: timestamp)
            }
            
            // Extract view count and time spent
            let viewCount = data["viewCount"] as? Int ?? 0
            let timeSpentSeconds = data["timeSpentSeconds"] as? Int ?? 0
            
            let ownerId = data["ownerId"] as? String ?? ""
            
            // Create the PublicNotebook with the notebook we just created
            var publicNotebook = PublicNotebook(
                firestoreId: document.documentID,
                notebook: notebook,
                author: ownerId,
                authorImage: self.userProfileImages[ownerId] ?? "person.circle.fill",
                likes: likes.count,
                comments: comments,
                isLiked: self.likedNotebooks.contains(document.documentID) ?? false,
                isSaved: false,
                feedDescription: data["feedDescription"] as? String ?? "",
                viewCount: viewCount,
                timeSpentSeconds: timeSpentSeconds
            )
            
            // Update the notebook's pages
            publicNotebook.notebook.pages = sortedPages
            
            // Asynchronously fetch the author's name
            self.db.collection("users").document(ownerId).getDocument { [weak self] userSnapshot, userError in
                guard let self = self, let userData = userSnapshot?.data() else {
                    print("❌ Error fetching user data for ID \(ownerId): \(userError?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                if let username = userData["username"] as? String {
                    // Update the notebook object in the published array on the main thread
                    DispatchQueue.main.async {
                        if let index = self.notebooks.firstIndex(where: { $0.firestoreId == publicNotebook.firestoreId }) {
                            self.notebooks[index].author = username
                        }
                    }
                }
            }
            
            return publicNotebook
        }
        
        // Calculate ranking scores and sort only on initial load or manual refresh
        calculateRankingScores()
    }
    
    // MARK: - Ranking Calculations
    // Calculate ranking scores for all notebooks
    private func calculateRankingScores() {
        let now = Date()
        
        for i in 0..<notebooks.count {
            let notebook = notebooks[i]
            
            // Time decay factor (posts get less relevant as they age)
            let ageInHours = now.timeIntervalSince(notebook.notebook.createdAt) / 3600
            let timeDecay = 1.0 / (1.0 + log(max(ageInHours, 1)))
            
            // Engagement score
            let engagementScore = calculateEngagementScore(notebook)
            
            // User relevance score
            let userRelevanceScore = calculateUserRelevanceScore(notebook)
            
            // Quality score
            let qualityScore = calculateQualityScore(notebook)
            
            // ML-based recommendation score (simplified for now)
            let recommendationScore = 0.5 // Default middle score since we don't have ML yet
            
            // Combine all factors into final ranking score
            let finalScore = (
                0.3 * engagementScore +
                0.2 * userRelevanceScore +
                0.2 * qualityScore +
                0.3 * recommendationScore
            ) * timeDecay
            
            notebooks[i].rankingScore = finalScore
            
            // Debug logging
            print("\nRanking components for notebook '\(notebook.notebook.title)':")
            print("Time decay (age: \(Int(ageInHours))h): \(String(format: "%.3f", timeDecay))")
            print("Engagement score: \(String(format: "%.3f", engagementScore))")
            print("- Views: \(notebook.viewCount)")
            print("- Likes: \(notebook.likes)")
            print("- Comments: \(notebook.comments.count)")
            print("- Time spent: \(notebook.timeSpentSeconds)s")
            print("User relevance: \(String(format: "%.3f", userRelevanceScore))")
            print("Quality score: \(String(format: "%.3f", qualityScore))")
            print("Final ranking score: \(String(format: "%.3f", finalScore))")
            print("----------------------------------------")
        }
        
        // Sort notebooks by ranking score
        notebooks.sort { $0.rankingScore > $1.rankingScore }
        
        // Debug log final order
        print("\nFinal notebook order:")
        for notebook in notebooks {
            print("\(notebook.notebook.title): \(String(format: "%.3f", notebook.rankingScore))")
        }
    }
    
    // Calculate engagement score based on user interactions
    private func calculateEngagementScore(_ notebook: PublicNotebook) -> Double {
        let viewWeight = 1.0
        let likeWeight = 2.0
        let commentWeight = 3.0
        let timeSpentWeight = 0.001 // per second
        
        let viewScore = Double(notebook.viewCount) * viewWeight
        let likeScore = Double(notebook.likes) * likeWeight
        let commentScore = Double(notebook.comments.count) * commentWeight
        let timeSpentScore = Double(notebook.timeSpentSeconds) * timeSpentWeight
        
        let totalScore = viewScore + likeScore + commentScore + timeSpentScore
        let normalizedScore = min(1.0, totalScore / 100.0) // Normalize to 0-1 range
        
        return normalizedScore
    }
    
    // Calculate relevance score based on user preferences
    private func calculateUserRelevanceScore(_ notebook: PublicNotebook) -> Double {
        var score = 0.0
        
        // Check recency and frequency of interactions with this notebook
        if let interactions = userInteractionHistory[notebook.firestoreId] {
            let now = Date()
            for interaction in interactions {
                let hoursAgo = now.timeIntervalSince(interaction) / 3600
                if hoursAgo < 24 {
                    score += 0.1 * (24 - hoursAgo) / 24
                }
            }
        }
        
        return min(1.0, score)
    }
    
    // Calculate quality score based on content attributes
    private func calculateQualityScore(_ notebook: PublicNotebook) -> Double {
        var score = 0.0
        
        // Content length/depth score
        let pageScore = min(1.0, Double(notebook.notebook.pages.count) / 10.0) * 0.4
        
        // Description quality score
        let descriptionWords = notebook.notebook.description?.split(separator: " ").count ?? 0
        let descriptionScore = min(1.0, Double(descriptionWords) / 20.0) * 0.3
        
        // Average content length score
        let avgContentLength = notebook.notebook.pages.reduce(0) { $0 + $1.content.count } / max(1, notebook.notebook.pages.count)
        let contentScore = min(1.0, Double(avgContentLength) / 500.0) * 0.3
        
        score = pageScore + descriptionScore + contentScore
        
        return min(1.0, score)
    }
    
    // Track user interaction with a notebook
    func trackInteraction(notebookId: String, interactionType: String) {
        let now = Date()
        userInteractionHistory[notebookId, default: []].append(now)
        
        // Update user preferences based on interaction
        if let notebook = notebooks.first(where: { $0.firestoreId == notebookId }) {
            // Remove tags-related code since Notebook doesn't have tags
            
            // Add interaction to recommendation engine
            let value = normalizeInteractionValue(type: interactionType)
            let interaction = UserInteraction(
                userId: currentUserId,
                notebookId: notebookId,
                interactionType: InteractionType(rawValue: interactionType) ?? .view,
                timestamp: now,
                value: value
            )
            recommendationEngine.addInteraction(interaction)
        }
        
        // Recalculate ranking scores
        calculateRankingScores()
    }
    
    // Update view count and time spent
    func updateViewMetrics(notebookId: String, timeSpentSeconds: Int) {
        if let index = notebooks.firstIndex(where: { $0.firestoreId == notebookId }) {
            notebooks[index].viewCount += 1
            notebooks[index].timeSpentSeconds += timeSpentSeconds
            
            // Add view interaction to recommendation engine
            let normalizedTimeSpent = min(1.0, Double(timeSpentSeconds) / 300.0) // Normalize to 0-1 range (max 5 minutes)
            let interaction = UserInteraction(
                userId: currentUserId,
                notebookId: notebookId,
                interactionType: .timeSpent,
                timestamp: Date(),
                value: normalizedTimeSpent
            )
            recommendationEngine.addInteraction(interaction)
            
            calculateRankingScores()
        }
    }
    
    // Update share count
    func incrementShareCount(for notebook: PublicNotebook) {
        if let index = notebooks.firstIndex(where: { $0.firestoreId == notebook.firestoreId }) {
            notebooks[index].shareCount += 1
            calculateRankingScores()
        }
    }
    
    // Override existing toggleSave to update save count
    func toggleSave(for notebook: PublicNotebook) {
        if let index = notebooks.firstIndex(where: { $0.firestoreId == notebook.firestoreId }) {
            notebooks[index].isSaved.toggle()
            if notebooks[index].isSaved {
                notebooks[index].saveCount += 1
            }
            trackInteraction(notebookId: notebook.firestoreId, interactionType: "save")
        }
    }
    
    // Override existing toggleLike to track interaction
    func toggleLike(for notebook: PublicNotebook) {
        guard let index = notebooks.firstIndex(where: { $0.firestoreId == notebook.firestoreId }) else { return }
        
        // Update local state
            notebooks[index].isLiked.toggle()
            notebooks[index].likes += notebooks[index].isLiked ? 1 : -1
        
        // Update user's likedNotebooks in local cache
        if notebooks[index].isLiked {
            likedNotebooks.insert(notebook.firestoreId)
        } else {
            likedNotebooks.remove(notebook.firestoreId)
        }
        
        // Update Firestore - both the notebook document and user document
        let batch = db.batch()
        
        // Update notebook's likes array
        let notebookRef = db.collection("notebooks").document(notebook.firestoreId)
        if notebooks[index].isLiked {
            batch.updateData([
                "likes": FieldValue.arrayUnion([currentUserId])
            ], forDocument: notebookRef)
        } else {
            batch.updateData([
                "likes": FieldValue.arrayRemove([currentUserId])
            ], forDocument: notebookRef)
        }
        
        // Update user's likedNotebooks array
        let userRef = db.collection("users").document(currentUserId)
        if notebooks[index].isLiked {
            batch.updateData([
                "likedNotebooks": FieldValue.arrayUnion([notebook.firestoreId])
            ], forDocument: userRef)
        } else {
            batch.updateData([
                "likedNotebooks": FieldValue.arrayRemove([notebook.firestoreId])
            ], forDocument: userRef)
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error updating like status: \(error.localizedDescription)")
            }
        }
    }
    
    // Modify addComment to use the new local update function
    func addComment(_ comment: String, to notebook: PublicNotebook) {
        guard let index = notebooks.firstIndex(where: { $0.firestoreId == notebook.firestoreId }) else { return }
        
        let userRef = db.collection("users").document(currentUserId)
        userRef.getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let userData = snapshot?.data(),
                  let username = userData["username"] as? String else {
                print("Error fetching username: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let newComment = NotebookComment(
                username: username,
                text: comment,
                timestamp: Date()
            )
            
            // Update local state without re-sorting
            self.updateNotebookLocally(notebookId: notebook.firestoreId) { notebook in
                notebook.comments.append(newComment)
            }
            
            // Update Firestore
            let docRef = self.db.collection("notebooks").document(notebook.firestoreId)
            let commentData: [String: Any] = [
                "username": username,
                "text": newComment.text,
                "timestamp": Timestamp(date: newComment.timestamp)
            ]
            
            docRef.updateData([
                "comments": FieldValue.arrayUnion([commentData])
            ]) { error in
                if let error = error {
                    print("Error adding comment: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Add a new function for updating a single notebook without re-sorting
    private func updateNotebookLocally(notebookId: String, updateAction: (inout PublicNotebook) -> Void) {
        if let index = notebooks.firstIndex(where: { $0.firestoreId == notebookId }) {
            var updatedNotebook = notebooks[index]
            updateAction(&updatedNotebook)
            notebooks[index] = updatedNotebook
        }
    }
    
    // Helper function to normalize interaction values
    private func normalizeInteractionValue(type: String) -> Double {
        switch type {
        case "like":
            return 0.8
        case "comment":
            return 1.0
        case "save":
            return 0.9
        case "share":
            return 0.7
        case "view":
            return 0.3
        default:
            return 0.1
        }
    }
    
    func fetchUserNotebooks() {
        print("Fetching notebooks for user: \(currentUserId)") // Debug log
        
        db.collection("notebooks")
            .whereField("ownerId", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching user notebooks: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self,
                      let documents = snapshot?.documents else {
                    print("No documents found")
                    return
                }
                
                print("Found \(documents.count) notebooks for user")
                
                // Create a Set to track processed notebook IDs
                var processedIds = Set<String>()
                
                // Clear existing notebooks first
                self.userNotebooks.removeAll()
                
                // Process each document
                for document in documents {
                    let data = document.data()
                    let notebookId = document.documentID
                    
                    // Skip if we've already processed this notebook
                    guard !processedIds.contains(notebookId) else {
                        print("Skipping duplicate notebook: \(data["title"] ?? "Untitled")")
                        continue
                    }
                    
                    print("Processing notebook: \(data["title"] ?? "Untitled")")
                    
                    // Convert Firestore Timestamp to Date
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Extract and convert pages array
                    let pagesData = data["pages"] as? [[String: Any]] ?? []
                    let pages = pagesData.compactMap { pageData -> Page? in
                        guard let id = pageData["id"] as? String,
                              let content = pageData["content"] as? String,
                              let typeString = pageData["type"] as? String,
                              let type = PageType(rawValue: typeString),
                              let order = pageData["order"] as? Int,
                              let createdAt = (pageData["createdAt"] as? Timestamp)?.dateValue(),
                              let updatedAt = (pageData["updatedAt"] as? Timestamp)?.dateValue()
                        else {
                            return nil
                        }
                        
                        // Decode canvas elements
                        let drawingData = pageData["drawingData"] as? Data
                        
                        let textBoxes = (pageData["textBoxes"] as? [[String: Any]])?.compactMap { boxDict -> CanvasTextBoxModel? in
                            guard let idString = boxDict["id"] as? String,
                                  let id = UUID(uuidString: idString),
                                  let text = boxDict["text"] as? String,
                                  let positionDict = boxDict["position"] as? [String: CGFloat],
                                  let x = positionDict["x"],
                                  let y = positionDict["y"] else {
                                return nil
                            }
                            return CanvasTextBoxModel(
                                id: id,
                                text: text,
                                position: CGPointCodable(CGPoint(x: x, y: y))
                            )
                        }
                        
                        let images = (pageData["images"] as? [[String: Any]])?.compactMap { imgDict -> CanvasImageModel? in
                            guard let idString = imgDict["id"] as? String,
                                  let id = UUID(uuidString: idString),
                                  let imageUrl = imgDict["imageUrl"] as? String,
                                  let positionDict = imgDict["position"] as? [String: CGFloat],
                                  let x = positionDict["x"],
                                  let y = positionDict["y"] else {
                                return nil
                            }
                            return CanvasImageModel(
                                id: id,
                                imageData: nil,
                                imageUrl: imageUrl,
                                position: CGPointCodable(CGPoint(x: x, y: y))
                            )
                        }
                        
                        return Page(
                            id: id,
                            content: content,
                            type: type,
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            order: order,
                            drawingData: drawingData,
                            textBoxes: textBoxes,
                            images: images
                        )
                    }
                    
                    // Sort pages by order
                    let sortedPages = pages.sorted { $0.order < $1.order }
                    
                    let notebook = PublicNotebook(
                        firestoreId: notebookId,
                        notebook: Notebook(
                            id: notebookId,
                            title: data["title"] as? String ?? "",
                            description: data["description"] as? String,
                            ownerId: self.currentUserId,
                            isPublic: data["isPublic"] as? Bool ?? false,
                            isPinned: data["isPinned"] as? Bool ?? false,
                            isFavorite: data["isFavorite"] as? Bool ?? false,
                            createdAt: createdAt,
                            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                            pages: sortedPages,
                            lastViewedPageIndex: data["lastViewedPageIndex"] as? Int ?? 0,
                            coverImage: data["coverImage"] as? String ?? "Blue"
                        ),
                        author: self.currentUserId,
                        authorImage: self.userProfileImages[self.currentUserId] ?? "person.circle.fill",
                        likes: 0,
                        comments: [],
                        isLiked: false,
                        isSaved: false,
                        feedDescription: data["feedDescription"] as? String ?? ""
                    )
                    
                    // Add to processed IDs
                    processedIds.insert(notebookId)
                    
                    // Add to userNotebooks array
                    self.userNotebooks.append(notebook)
                    print("Added notebook: \(notebook.notebook.title)")
                }
                
                print("Final userNotebooks count: \(self.userNotebooks.count)")
            }
    }
    
    func makeNotebookPublic(_ notebook: PublicNotebook, description: String, completion: @escaping (Bool) -> Void) {
        let notebookRef = db.collection("notebooks").document(notebook.firestoreId)
        
        // First, update the ownerId to use the Firebase Auth user ID
        notebookRef.updateData([
            "ownerId": currentUserId,
            "isPublic": true,
            "sharedAt": Timestamp(date: Date()),
            "feedDescription": description
        ]) { error in
            if let error = error {
                print("Error making notebook public: \(error.localizedDescription)")
                completion(false)
            } else {
                // Refresh the feed to show the newly shared notebook
                self.fetchNotebooks()
                completion(true)
            }
        }
    }
    
    func makeNotebookPrivate(_ notebook: PublicNotebook) {
        let notebookRef = db.collection("notebooks").document(notebook.firestoreId)
        
        notebookRef.updateData([
            "isPublic": false,
            "sharedAt": FieldValue.delete()
        ]) { error in
            if let error = error {
                print("Error making notebook private: \(error.localizedDescription)")
            } else {
                // Remove the notebook from the feed
                self.notebooks.removeAll { $0.firestoreId == notebook.firestoreId }
            }
        }
    }
    
    // Add a function for manual refresh
    func refreshNotebooks() {
        fetchNotebooks()
    }
}

struct NotebookFeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var isRefreshing = false
    @State private var showingShareSheet = false
    @State private var selectedNotebook: PublicNotebook? = nil
    @State private var selectedPageIndex: Int = 0
    @State private var rotation: Double = 0
    @State private var isFlipping = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.notebooks) { notebook in
                            PublicNotebookView(notebook: notebook, viewModel: viewModel, selectedNotebook: $selectedNotebook)
                                .padding(.bottom, 8)
                                .id(notebook.firestoreId)
                        }
                    }
                    .blur(radius: selectedNotebook != nil ? 10 : 0)
                }
                .refreshable {
                    await refreshData()
                }
                .navigationTitle("Explore")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingShareSheet = true
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    ShareNotebookView(viewModel: viewModel)
                }
                
                // Expanded notebook view overlay
                if let selectedNotebook = selectedNotebook {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                self.selectedNotebook = nil
                                self.selectedPageIndex = 0
                                self.rotation = 0
                            }
                        }
                    
                    VStack(spacing: 0) {
                        // Page selector header
                        HStack {
                            Text("Page \(selectedPageIndex + 1) of \(selectedNotebook.notebook.pages.count + 1)")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                withAnimation(.spring()) {
                                    self.selectedNotebook = nil
                                    self.selectedPageIndex = 0
                                    self.rotation = 0
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        
                        // 3D Notebook View
                        ZStack {
                            // Cover Page (Index 0)
                            if selectedPageIndex == 0 {
                                VStack {
                                    Image(selectedNotebook.notebook.coverImage)
                                        .resizable()
                                        .aspectRatio(4/5, contentMode: .fit)
                                }
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(12)
                                .rotation3DEffect(
                                    .degrees(rotation),
                                    axis: (x: 0, y: 1, z: 0),
                                    anchor: .leading,
                                    perspective: 0.5
                                )
                            }
                            
                            // Content Pages (Index 1 onwards)
                            if selectedPageIndex > 0 && selectedPageIndex - 1 < selectedNotebook.notebook.pages.count {
                                FeedPageView(
                                    page: selectedNotebook.notebook.pages[selectedPageIndex - 1],
                                    rotation: rotation
                                )
                            }
                        }
                        .frame(width: 360, height: 400)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if !isFlipping {
                                        rotation = Double(value.translation.width / 2)
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.width < -100 && selectedPageIndex < selectedNotebook.notebook.pages.count {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            rotation = 180
                                            isFlipping = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            selectedPageIndex += 1
                                            rotation = 0
                                            isFlipping = false
                                        }
                                    } else if value.translation.width > 100 && selectedPageIndex > 0 {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            rotation = -180
                                            isFlipping = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            selectedPageIndex -= 1
                                            rotation = 0
                                            isFlipping = false
                                        }
                                    } else {
                                        withAnimation {
                                            rotation = 0
                                        }
                                    }
                                }
                        )
                        
                        // Page Navigation
                        HStack {
                            Button(action: {
                                if selectedPageIndex > 0 {
                                    // Left arrow: go back
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        rotation = 180
                                        isFlipping = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        selectedPageIndex -= 1
                                        rotation = 0
                                        isFlipping = false
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title)
                                    .foregroundColor(selectedPageIndex > 0 ? .blue : .gray)
                            }
                            .disabled(selectedPageIndex == 0)
                            
                            Spacer()
                            
                            Button(action: {
                                if selectedPageIndex < selectedNotebook.notebook.pages.count {
                                    // Right arrow: go forward
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        rotation = -180
                                        isFlipping = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        selectedPageIndex += 1
                                        rotation = 0
                                        isFlipping = false
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title)
                                    .foregroundColor(selectedPageIndex < selectedNotebook.notebook.pages.count ? .blue : .gray)
                            }
                            .disabled(selectedPageIndex == selectedNotebook.notebook.pages.count)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        viewModel.fetchNotebooks()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

struct ShareNotebookView: View {
    @ObservedObject var viewModel: FeedViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedNotebook: PublicNotebook?
    @State private var description: String = ""
    @State private var showingDescriptionSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.userNotebooks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No notebooks to share")
                            .font(.headline)
                        Text("Create a notebook first to share it with others")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.userNotebooks) { notebook in
                            Button(action: {
                                selectedNotebook = notebook
                                showingDescriptionSheet = true
                            }) {
                                HStack {
                                    Image(notebook.notebook.coverImage)
                                        .resizable()
                                        .aspectRatio(4/5, contentMode: .fit)
                                        .frame(width: 60, height: 75)
                                        .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(notebook.notebook.title)
                                            .font(.headline)
                                        Text("\(notebook.notebook.pages.count) pages")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        if notebook.notebook.isPublic {
                                            Text("Currently shared")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if notebook.notebook.isPublic {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Share to Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDescriptionSheet) {
                if let notebook = selectedNotebook {
                    DescriptionInputView(
                        notebook: notebook,
                        description: $description,
                        viewModel: viewModel,
                        dismiss: dismiss
                    )
                }
            }
            .onAppear {
                viewModel.fetchUserNotebooks()
            }
        }
    }
}

struct DescriptionInputView: View {
    let notebook: PublicNotebook
    @Binding var description: String
    @ObservedObject var viewModel: FeedViewModel
    let dismiss: DismissAction
    @Environment(\.dismiss) var sheetDismiss
    @State private var isSharing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Notebook preview
                VStack(alignment: .leading, spacing: 12) {
                    Image(notebook.notebook.coverImage)
                        .resizable()
                        .aspectRatio(4/5, contentMode: .fit)
                        .frame(height: 200)
                        .cornerRadius(12)
                    
                    Text(notebook.notebook.title)
                        .font(.headline)
                    
                    Text("\(notebook.notebook.pages.count) pages")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                
                // Description input
                VStack(alignment: .leading, spacing: 8) {
                    Text("What would you like to share about this notebook?")
                        .font(.headline)
                    
                    TextEditor(text: $description)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Share to Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        sheetDismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isSharing = true
                        viewModel.makeNotebookPublic(notebook, description: description) { success in
                            isSharing = false
                            if success {
                                dismiss()
                            }
                        }
                    }) {
                        if isSharing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Share")
                        }
                    }
                    .disabled(description.isEmpty || isSharing)
                }
            }
        }
    }
}

struct PublicNotebookDetailView: View {
    let notebook: PublicNotebook
    @State private var selectedPageIndex: Int = 0
    @State private var rotation: Double = 0
    @State private var isFlipping = false

    var body: some View {
        VStack(spacing: 0) {
            // Page selector header
            HStack {
                // Add 1 to account for cover page
                Text("Page \(selectedPageIndex + 1) of \(notebook.notebook.pages.count + 1)")
                    .font(.headline)
                Spacer()
            }
            .padding()

            // 3D Notebook View
            ZStack {
                // Cover Page (Index 0)
                if selectedPageIndex == 0 {
                    VStack {
                        Text(notebook.notebook.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Image(notebook.notebook.coverImage)
                            .resizable()
                            .aspectRatio(4/5, contentMode: .fit)
                        .rotation3DEffect(
                            .degrees(rotation),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.5
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(12)
                }

                // Content Pages (Index 1 onwards)
                if selectedPageIndex > 0 && selectedPageIndex - 1 < notebook.notebook.pages.count {
                    FeedPageView(
                        page: notebook.notebook.pages[selectedPageIndex - 1],
                        rotation: rotation
                    )
                }
            }
            .frame(height: 500)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isFlipping {
                            rotation = Double(value.translation.width / 2)
                        }
                    }
                    .onEnded { value in
                        // Add 1 to account for cover page
                        if value.translation.width < -100 && selectedPageIndex < notebook.notebook.pages.count {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                rotation = -180
                                isFlipping = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                selectedPageIndex += 1
                                rotation = 0
                                isFlipping = false
                            }
                        } else if value.translation.width > 100 && selectedPageIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                rotation = 180
                                isFlipping = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                selectedPageIndex -= 1
                                rotation = 0
                                isFlipping = false
                            }
                        } else {
                            withAnimation {
                                rotation = 0
                            }
                        }
                    }
            )

            // Page Navigation
            HStack {
                Button(action: {
                    if selectedPageIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            rotation = 180
                            isFlipping = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            selectedPageIndex -= 1
                            rotation = 0
                            isFlipping = false
                        }
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundColor(selectedPageIndex > 0 ? .blue : .gray)
                }
                .disabled(selectedPageIndex == 0)

                Spacer()

                Button(action: {
                    // Add 1 to account for cover page
                    if selectedPageIndex < notebook.notebook.pages.count {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            rotation = -180
                            isFlipping = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            selectedPageIndex += 1
                            rotation = 0
                            isFlipping = false
                        }
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                        .foregroundColor(selectedPageIndex < notebook.notebook.pages.count ? .blue : .gray)
                }
                .disabled(selectedPageIndex == notebook.notebook.pages.count)
            }
            .padding()
        }
        .navigationTitle(notebook.notebook.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PublicNotebookView: View {
    @ObservedObject var notebook: PublicNotebook
    @ObservedObject var viewModel: FeedViewModel
    @Binding var selectedNotebook: PublicNotebook?
    @State private var showingComments = false
    @State private var newComment = ""
    @State private var viewStartTime: Date? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Notebook Header
            HStack {
                if let profileImageURL = viewModel.userProfileImages[notebook.author] {
                    AsyncImage(url: URL(string: profileImageURL)) { image in
                        image
                    .resizable()
                    .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading) {
                    Text(notebook.notebook.title)
                        .font(.headline)
                    Text("by \(notebook.author)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                }
            }
            .padding(.horizontal)
            
            // Notebook Cover
            Image(notebook.notebook.coverImage)
                .resizable()
                .aspectRatio(4/5, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .cornerRadius(12)
                .padding(.horizontal)
                .onTapGesture {
                    withAnimation(.spring()) {
                        selectedNotebook = notebook
                    }
                }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: { viewModel.toggleLike(for: notebook) }) {
                    Image(systemName: notebook.isLiked ? "heart.fill" : "heart")
                        .foregroundColor(notebook.isLiked ? .red : .primary)
                }
                
                Button(action: { showingComments = true }) {
                    Image(systemName: "message")
                }
                
                ShareLink(item: "Check out this notebook: \(notebook.notebook.title) - Link ID: \(notebook.firestoreId)") {
                    Image(systemName: "square.and.arrow.up")
                }
                .onTapGesture {
                    // Optionally increment share count here, although ShareLink handles the interaction
                    viewModel.incrementShareCount(for: notebook)
                }
                
                Spacer()
                
                Button(action: { viewModel.toggleSave(for: notebook) }) {
                    Image(systemName: notebook.isSaved ? "bookmark.fill" : "bookmark")
                }
            }
            .font(.system(size: 20))
            .padding(.horizontal)
            
            // Likes
            Text("\(notebook.likes) likes")
                .font(.headline)
                .padding(.horizontal)
            
            // Description
            Text(notebook.notebook.description ?? "")
                .font(.body)
                .padding(.horizontal)
            
            // Notebook Info
            HStack {
                Image(systemName: "doc.text")
                Text("\(notebook.notebook.pages.count) pages")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            // Timestamp
            Text(notebook.notebook.createdAt, formatter: DateFormatter.feedDate)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            // Comments Preview
            if !notebook.comments.isEmpty {
                Button(action: { showingComments = true }) {
                    Text("View all \(notebook.comments.count) comments")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingComments) {
            NotebookCommentsView(notebook: notebook, viewModel: viewModel)
        }
        .onAppear {
            viewStartTime = Date()
        }
        .onDisappear {
            if let startTime = viewStartTime {
                let timeSpent = Int(Date().timeIntervalSince(startTime))
                viewModel.updateViewMetrics(notebookId: notebook.firestoreId, timeSpentSeconds: timeSpent)
            }
        }
    }
}

struct NotebookCommentsView: View {
    let notebook: PublicNotebook
    @ObservedObject var viewModel: FeedViewModel
    @State private var newComment = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(notebook.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.username)
                                .font(.headline)
                            Text(comment.text)
                                .font(.body)
                            Text(formattedTimeAgo(from: comment.timestamp))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        if !newComment.isEmpty {
                            viewModel.addComment(newComment, to: notebook)
                            newComment = ""
                        }
                    }) {
                        Text("Post")
                            .fontWeight(.semibold)
                    }
                    .disabled(newComment.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Add a helper function for time formatting
    func formattedTimeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .day, .hour, .minute, .second], from: date, to: now)
        
        if let year = components.year, year > 0 {
            return "\(year)y ago"
        } else if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else if let second = components.second, second >= 0 {
            return "\(second)s ago"
        }
        return "just now"
    }
}

// Add a static date formatter for feed dates
extension DateFormatter {
    static let feedDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
} 

// Add a helper for getting text size (Might be needed for precise positioning if we don't use .position() directly)
extension String {
    func heightOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let boundingRect = (self as NSString).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: fontAttributes, context: nil)
        return ceil(boundingRect.height)
    }
    
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let boundingRect = (self as NSString).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: fontAttributes, context: nil)
        return ceil(boundingRect.width)
    }
}

// Helper view for page lines
struct PageLines: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<20) { _ in
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 1)
                    .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
    }
}

// Helper view for text boxes
struct PageTextBox: View {
    let box: CanvasTextBoxModel
    
    var body: some View {
        Text(box.text)
            .font(.body)
            .frame(minWidth: 60, maxWidth: 180, minHeight: 32, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .background(Color.clear)
            .cornerRadius(8)
            .position(CGPoint(x: box.position.x, y: box.position.y))
    }
}

// Helper view for images
struct PageImage: View {
    let image: CanvasImageModel
    
    var body: some View {
        if let imageUrl = image.imageUrl,
           let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                case .failure:
                    Image(systemName: "photo")
                        .frame(width: 100, height: 100)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 100, height: 100)
            .position(CGPoint(x: image.position.x, y: image.position.y))
        }
    }
}

// Main page content view
struct PageContent: View {
    let page: Page
    
    var body: some View {
        ZStack {
            // Page background
            Rectangle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 320, height: 400)
            
            // Page lines
            PageLines()
            
            // Text content
            if page.type == .text {
                Text(page.content)
                    .font(.body)
                    .foregroundColor(.black.opacity(0.8))
                    .padding()
            }
            
            // Text boxes
            if let textBoxes = page.textBoxes {
                ForEach(textBoxes) { box in
                    PageTextBox(box: box)
                }
            }
            
            // Images
            if let images = page.images {
                ForEach(images) { img in
                    PageImage(image: img)
                }
            }
        }
    }
}

// Feed page view with exact positioning
struct FeedPageView: View {
    let page: Page
    let rotation: Double
    
    var body: some View {
        ZStack {
            // Background
            Color.white
            
            // Content container with exact positioning
            ZStack {
                // Text content
                if page.type == .text {
                    Text(page.content)
                        .font(.body)
                        .foregroundColor(.black)
                        .padding()
                }
                
                // Text boxes with exact positioning
                if let textBoxes = page.textBoxes {
                    ForEach(textBoxes) { box in
                        Text(box.text)
                            .font(.body)
                            .foregroundColor(.black)
                            .frame(
                                width: box.size?.width ?? 180,
                                height: box.size?.height ?? 100,
                                alignment: .topLeading
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(8)
                            .background(Color.clear)
                            .cornerRadius(8)
                            .position(
                                x: min(max(box.position.x, 50), 270), // Constrain x position
                                y: min(max(box.position.y, 50), 350)  // Constrain y position
                            )
                    }
                }
                
                // Images with exact positioning
                if let images = page.images {
                    ForEach(images) { img in
                        if let imageUrl = img.imageUrl,
                           let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: img.size?.width ?? 100, height: img.size?.height ?? 100)
                                case .failure:
                                    Image(systemName: "photo")
                                        .frame(width: img.size?.width ?? 100, height: img.size?.height ?? 100)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: img.size?.width ?? 100, height: img.size?.height ?? 100)
                            .position(
                                x: min(max(img.position.x, 50), 270), // Constrain x position
                                y: min(max(img.position.y, 50), 350)  // Constrain y position
                            )
                        }
                    }
                }
            }
            .frame(width: 320, height: 400)
        }
        .frame(width: 320, height: 400)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.5
        )
    }
}
