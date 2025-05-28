//
//  NotebookFeedView.swift
//  L'Ink
//
//  Created by Daniela on 4/28/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NotebookPage: Identifiable {
    let id: String
    let content: String
    let type: String
    let order: Int
    let createdAt: Date
    let updatedAt: Date
}

struct PublicNotebook: Identifiable {
    let id = UUID()
    let firestoreId: String
    let title: String
    let author: String
    let authorImage: String
    let coverImage: String
    let description: String
    let tags: [String]
    var likes: Int
    var comments: [NotebookComment]
    let timestamp: Date
    let pages: [NotebookPage]  // Store actual pages instead of just count
    var isLiked: Bool = false
    var isSaved: Bool = false
    let prompts: [String]
    
    // Ranking score properties
    var viewCount: Int = 0
    var saveCount: Int = 0
    var shareCount: Int = 0
    var timeSpentSeconds: Int = 0
    var rankingScore: Double = 0.0
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
            fetchLikedNotebooks()
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
    
    private func fetchNotebooks() {
        db.collection("notebooks")
            .whereField("isPublic", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching notebooks: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.notebooks = documents.compactMap { document in
                    let data = document.data()
                    
                    // Convert Firestore Timestamp to Date
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Extract and convert pages array
                    let pagesData = data["pages"] as? [[String: Any]] ?? []
                    let pages = pagesData.compactMap { pageData -> NotebookPage? in
                        guard let id = pageData["id"] as? String,
                              let content = pageData["content"] as? String,
                              let type = pageData["type"] as? String,
                              let order = pageData["order"] as? Int,
                              let createdAt = (pageData["createdAt"] as? Timestamp)?.dateValue(),
                              let updatedAt = (pageData["updatedAt"] as? Timestamp)?.dateValue()
                        else {
                            return nil
                        }
                        return NotebookPage(
                            id: id,
                            content: content,
                            type: type,
                            order: order,
                            createdAt: createdAt,
                            updatedAt: updatedAt
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
                    
                    return PublicNotebook(
                        firestoreId: document.documentID,
                        title: data["title"] as? String ?? "",
                        author: data["ownerId"] as? String ?? "",
                        authorImage: "person.circle.fill",
                        coverImage: "Logo",
                        description: data["description"] as? String ?? "",
                        tags: [],
                        likes: likes.count,
                        comments: comments,
                        timestamp: createdAt,
                        pages: sortedPages,
                        isLiked: self?.likedNotebooks.contains(document.documentID) ?? false,
                        prompts: []
                    )
                }
            }
    }
    
    // Calculate ranking scores for all notebooks
    private func calculateRankingScores() {
        let now = Date()
        
        for i in 0..<notebooks.count {
            let notebook = notebooks[i]
            
            // Time decay factor (posts get less relevant as they age)
            let ageInHours = now.timeIntervalSince(notebook.timestamp) / 3600
            let timeDecay = 1.0 / (1.0 + log(max(ageInHours, 1)))
            
            // Engagement score
            let engagementScore = calculateEngagementScore(notebook)
            
            // User relevance score
            let userRelevanceScore = calculateUserRelevanceScore(notebook)
            
            // Quality score
            let qualityScore = calculateQualityScore(notebook)
            
            // ML-based recommendation score
            let recommendationScore = recommendationEngine.getPredictedScore(
                userId: currentUserId,
                notebookId: notebook.firestoreId
            )
            
            // Combine all factors into final ranking score
            let finalScore = (
                0.3 * engagementScore +
                0.2 * userRelevanceScore +
                0.2 * qualityScore +
                0.3 * recommendationScore // Add ML-based score
            ) * timeDecay
            
            notebooks[i].rankingScore = finalScore
        }
        
        // Sort notebooks by ranking score
        notebooks.sort { $0.rankingScore > $1.rankingScore }
    }
    
    // Calculate engagement score based on user interactions
    private func calculateEngagementScore(_ notebook: PublicNotebook) -> Double {
        let viewWeight = 1.0
        let likeWeight = 2.0
        let commentWeight = 3.0
        let saveWeight = 4.0
        let shareWeight = 2.5
        let timeSpentWeight = 0.001 // per second
        
        let viewScore = Double(notebook.viewCount) * viewWeight
        let likeScore = Double(notebook.likes) * likeWeight
        let commentScore = Double(notebook.comments.count) * commentWeight
        let saveScore = Double(notebook.saveCount) * saveWeight
        let shareScore = Double(notebook.shareCount) * shareWeight
        let timeSpentScore = Double(notebook.timeSpentSeconds) * timeSpentWeight
        
        let totalScore = viewScore + likeScore + commentScore + saveScore + shareScore + timeSpentScore
        let normalizedScore = min(1.0, totalScore / 1000.0) // Normalize to 0-1 range
        
        return normalizedScore
    }
    
    // Calculate relevance score based on user preferences
    private func calculateUserRelevanceScore(_ notebook: PublicNotebook) -> Double {
        var score = 0.0
        
        // Check if user has interacted with similar content
        let matchingTags = Set(notebook.tags).intersection(userPreferences)
        score += Double(matchingTags.count) * 0.2
        
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
        score += min(1.0, Double(notebook.pages.count) / 20.0) * 0.4
        
        // Description quality score
        let descriptionWords = notebook.description.split(separator: " ").count
        score += min(1.0, Double(descriptionWords) / 30.0) * 0.3
        
        // Prompts quality score
        score += min(1.0, Double(notebook.prompts.count) / 5.0) * 0.3
        
        return score
    }
    
    // Track user interaction with a notebook
    func trackInteraction(notebookId: String, interactionType: String) {
        let now = Date()
        userInteractionHistory[notebookId, default: []].append(now)
        
        // Update user preferences based on interaction
        if let notebook = notebooks.first(where: { $0.firestoreId == notebookId }) {
            userPreferences.formUnion(notebook.tags)
            
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
    
    // Override existing addComment to track interaction
    func addComment(_ comment: String, to notebook: PublicNotebook) {
        guard let index = notebooks.firstIndex(where: { $0.firestoreId == notebook.firestoreId }) else { return }
        
        // First fetch the user's data to get the username
        let userRef = db.collection("users").document(currentUserId)
        userRef.getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let userData = snapshot?.data(),
                  let username = userData["username"] as? String else {
                print("Error fetching username: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let newComment = NotebookComment(
                username: username, // Using the actual username from Firestore
                text: comment,
                timestamp: Date()
            )
            
            // Update local state
            self.notebooks[index].comments.append(newComment)
            
            // Update Firestore directly using the document ID
            let docRef = self.db.collection("notebooks").document(notebook.firestoreId)
            let commentData: [String: Any] = [
                "username": username, // Using the actual username
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
}

struct NotebookFeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.notebooks) { notebook in
                        PublicNotebookView(notebook: notebook, viewModel: viewModel)
                            .padding(.bottom, 8)
                    }
                }
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
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                        }
                    }
                }
            }
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        viewModel.loadMockData()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
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
                Text("Page \(selectedPageIndex + 1) of \(notebook.pages.count + 1)")
                    .font(.headline)
                Spacer()
            }
            .padding()

            // 3D Notebook View
            ZStack {
                // Cover Page (Index 0)
                if selectedPageIndex == 0 {
                    VStack {
                        Text(notebook.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Image(notebook.coverImage)
                            .resizable()
                            .aspectRatio(4/5, contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(12)
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .trailing,
                        perspective: 0.5
                    )
                }

                // Content Pages (Index 1 onwards)
                if selectedPageIndex > 0 && selectedPageIndex - 1 < notebook.pages.count {
                    VStack {
                        Text(notebook.pages[selectedPageIndex - 1].content)
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .cornerRadius(12)
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .trailing,
                        perspective: 0.5
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
                        if value.translation.width < -100 && selectedPageIndex < notebook.pages.count {
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
                    if selectedPageIndex < notebook.pages.count {
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
                        .foregroundColor(selectedPageIndex < notebook.pages.count ? .blue : .gray)
                }
                .disabled(selectedPageIndex == notebook.pages.count)
            }
            .padding()
        }
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PublicNotebookView: View {
    let notebook: PublicNotebook
    @ObservedObject var viewModel: FeedViewModel
    @State private var showingComments = false
    @State private var newComment = ""
    @State private var viewStartTime: Date? = nil
    
    var body: some View {
        NavigationLink(destination: PublicNotebookDetailView(notebook: notebook)) {
            VStack(alignment: .leading, spacing: 8) {
                // Notebook Header
                HStack {
                    Image(systemName: notebook.authorImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(notebook.title)
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
                Image(notebook.coverImage)
                    .resizable()
                    .aspectRatio(4/5, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .padding(.horizontal)

                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: { viewModel.toggleLike(for: notebook) }) {
                        Image(systemName: notebook.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(notebook.isLiked ? .red : .primary)
                    }
                    
                    Button(action: { showingComments = true }) {
                        Image(systemName: "message")
                    }
                    
                    Button(action: {
                        viewModel.incrementShareCount(for: notebook)
                        // Add your share sheet implementation here
                    }) {
                        Image(systemName: "square.and.arrow.up")
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
                Text(notebook.description)
                    .font(.body)
                    .padding(.horizontal)
                
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(notebook.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Notebook Info
                HStack {
                    Image(systemName: "doc.text")
                    Text("\(notebook.pages.count) pages")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                // Timestamp
                Text(notebook.timestamp, formatter: DateFormatter.feedDate)
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
                            Text(comment.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
                // Prompts
                if !notebook.prompts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(notebook.prompts, id: \.self) { prompt in
                                Button(action: { newComment = prompt }) {
                                    Text(prompt)
                                        .font(.caption)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
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
}

// Add a static date formatter for feed dates
extension DateFormatter {
    static let feedDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}
