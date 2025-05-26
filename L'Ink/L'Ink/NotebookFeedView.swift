//
//  NotebookFeedView.swift
//  L'Ink
//
//  Created by Daniela on 4/28/25.
//

import SwiftUI

struct PublicNotebook: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let authorImage: String
    let coverImage: String
    let description: String
    let tags: [String]
    var likes: Int
    var comments: [NotebookComment]
    let timestamp: Date
    let pageCount: Int
    var isLiked: Bool = false
    var isSaved: Bool = false
    let prompts: [String]
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
    
    init() {
        loadMockData()
    }
    
    func loadMockData() {
        notebooks = [
            PublicNotebook(
                title: "My Creative Writing Journey",
                author: "john_doe",
                authorImage: "person.circle.fill",
                coverImage: "Logo",
                description: "A collection of my creative writing pieces and poetry. Feel free to read and share your thoughts! #writing #poetry #creative",
                tags: ["writing", "poetry", "creative"],
                likes: 42,
                comments: [
                    NotebookComment(username: "jane_smith", text: "Your poetry is beautiful! Would love to see more.", timestamp: Date().addingTimeInterval(-3600)),
                    NotebookComment(username: "alex_dev", text: "The structure is really well thought out.", timestamp: Date().addingTimeInterval(-7200))
                ],
                timestamp: Date().addingTimeInterval(-3600),
                pageCount: 15,
                prompts: [
                    "What did you like most about this notebook?",
                    "How would you use this in your own work?",
                    "What would you add or change?"
                ]
            ),
            PublicNotebook(
                title: "Study Notes: Advanced Mathematics",
                author: "jane_smith",
                authorImage: "person.circle.fill",
                coverImage: "Logo",
                description: "Comprehensive notes covering calculus, linear algebra, and differential equations. Hope this helps other students! #math #study #education",
                tags: ["math", "study", "education"],
                likes: 28,
                comments: [
                    NotebookComment(username: "john_doe", text: "These notes are incredibly helpful! Thank you for sharing.", timestamp: Date().addingTimeInterval(-1800))
                ],
                timestamp: Date().addingTimeInterval(-7200),
                pageCount: 45,
                prompts: [
                    "Which topic did you find most challenging?",
                    "What would you like to see explained in more detail?"
                ]
            ),
            PublicNotebook(
                title: "Travel Journal: Japan",
                author: "alex_dev",
                authorImage: "person.circle.fill",
                coverImage: "Logo",
                description: "Photos, sketches, and stories from my trip to Japan. #travel #japan #adventure",
                tags: ["travel", "japan", "adventure"],
                likes: 67,
                comments: [
                    NotebookComment(username: "john_doe", text: "This makes me want to visit Japan!", timestamp: Date().addingTimeInterval(-5400)),
                    NotebookComment(username: "sarah_wilson", text: "Beautiful photos!", timestamp: Date().addingTimeInterval(-6000))
                ],
                timestamp: Date().addingTimeInterval(-10800),
                pageCount: 30,
                prompts: []
            ),
            PublicNotebook(
                title: "Recipe Book: Vegan Delights",
                author: "sarah_wilson",
                authorImage: "person.circle.fill",
                coverImage: "Logo",
                description: "A collection of my favorite vegan recipes. #vegan #cooking #recipes",
                tags: ["vegan", "cooking", "recipes"],
                likes: 53,
                comments: [
                    NotebookComment(username: "jane_smith", text: "Trying the lasagna tonight!", timestamp: Date().addingTimeInterval(-8000))
                ],
                timestamp: Date().addingTimeInterval(-14400),
                pageCount: 22,
                prompts: []
            ),
            PublicNotebook(
                title: "Art Portfolio 2024",
                author: "emma_artist",
                authorImage: "person.circle.fill",
                coverImage: "Logo",
                description: "My latest digital and traditional artworks. #art #portfolio #digitalart",
                tags: ["art", "portfolio", "digitalart"],
                likes: 88,
                comments: [
                    NotebookComment(username: "alex_dev", text: "Your style is so unique!", timestamp: Date().addingTimeInterval(-10000))
                ],
                timestamp: Date().addingTimeInterval(-20000),
                pageCount: 40,
                prompts: []
            )
        ]
    }
    
    func toggleLike(for notebook: PublicNotebook) {
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[index].isLiked.toggle()
            notebooks[index].likes += notebooks[index].isLiked ? 1 : -1
        }
    }
    
    func toggleSave(for notebook: PublicNotebook) {
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[index].isSaved.toggle()
        }
    }
    
    func addComment(_ comment: String, to notebook: PublicNotebook) {
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            let newComment = NotebookComment(
                username: "current_user",
                text: comment,
                timestamp: Date()
            )
            notebooks[index].comments.append(newComment)
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
                Text("Page \(selectedPageIndex + 1) of \(notebook.pageCount)")
                    .font(.headline)
                Spacer()
            }
            .padding()

            // 3D Notebook View
            ZStack {
                // Notebook Cover
                Image(notebook.coverImage)
                    .resizable()
                    .aspectRatio(4/5, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .trailing,
                        perspective: 0.5
                    )
                    .opacity(selectedPageIndex == 0 ? 1 : 0)

                // Pages
                ForEach(0..<notebook.pageCount, id: \.self) { index in
                    if index > 0 {
                        Text("Page \(index + 1)")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white)
                            .cornerRadius(12)
                            .rotation3DEffect(
                                .degrees(rotation),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: .trailing,
                                perspective: 0.5
                            )
                            .opacity(selectedPageIndex == index ? 1 : 0)
                    }
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
                        if value.translation.width < -100 && selectedPageIndex < notebook.pageCount - 1 {
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
                    if selectedPageIndex < notebook.pageCount - 1 {
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
                        .foregroundColor(selectedPageIndex < notebook.pageCount - 1 ? .blue : .gray)
                }
                .disabled(selectedPageIndex == notebook.pageCount - 1)
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
                    
                    Button(action: {}) {
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
                    Text("\(notebook.pageCount) pages")
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
