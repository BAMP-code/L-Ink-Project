//
//  NotebookFeedView.swift
//  L'Ink
//
//  Created by Daniela on 4/28/25.
//

import SwiftUI

struct NotebookFeedView: View {
    @State private var recentNotebooks: [FeedNotebook] = []
    @State private var sharedNotebooks: [FeedNotebook] = []
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Image(systemName: "plus.app")
                                .font(.system(size: 24))
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "heart")
                                .font(.system(size: 24))
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 24))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Segmented Control
                Picker("Feed Type", selection: $selectedTab) {
                    Text("Recent").tag(0)
                    Text("Shared").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 1),
                        GridItem(.flexible(), spacing: 1),
                        GridItem(.flexible(), spacing: 1)
                    ], spacing: 1) {
                        ForEach(selectedTab == 0 ? recentNotebooks : sharedNotebooks) { notebook in
                            FeedNotebookCell(notebook: notebook)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct FeedNotebookCell: View {
    let notebook: FeedNotebook
    @State private var isLiked = false
    @State private var likeCount = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User info and menu
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading) {
                    Text(notebook.userName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(notebook.location ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                }
            }
            .padding(.horizontal)
            
            // Notebook image
            Image(notebook.coverImage)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    isLiked.toggle()
                    likeCount += isLiked ? 1 : -1
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .primary)
                }
                
                Button(action: {}) {
                    Image(systemName: "bubble.right")
                }
                
                Button(action: {}) {
                    Image(systemName: "paperplane")
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "bookmark")
                }
            }
            .font(.system(size: 24))
            .padding(.horizontal)
            
            // Likes and caption
            VStack(alignment: .leading, spacing: 4) {
                Text("\(likeCount) likes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(notebook.userName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                + Text(" \(notebook.caption)")
                    .font(.subheadline)
                
                Text(notebook.timestamp)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(uiColor: .systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct RecentNotebooksList: View {
    let notebooks: [FeedNotebook]
    
    var body: some View {
        if notebooks.isEmpty {
            EmptyStateView(
                icon: "clock",
                title: "No Recent Notebooks",
                message: "Your recent notebooks will appear here"
            )
        } else {
            List {
                ForEach(notebooks) { notebook in
                    FeedNotebookRow(notebook: notebook)
                }
            }
        }
    }
}

struct SharedNotebooksList: View {
    let notebooks: [FeedNotebook]
    
    var body: some View {
        if notebooks.isEmpty {
            EmptyStateView(
                icon: "person.2",
                title: "No Shared Notebooks",
                message: "Notebooks shared with you will appear here"
            )
        } else {
            List {
                ForEach(notebooks) { notebook in
                    FeedNotebookRow(notebook: notebook)
                }
            }
        }
    }
}

struct FeedNotebookRow: View {
    let notebook: FeedNotebook
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: notebook.icon)
                .font(.title2)
                .foregroundColor(notebook.color)
                .frame(width: 40, height: 40)
                .background(notebook.color.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notebook.title)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.gray)
                    Text(notebook.owner)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(notebook.lastModified, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if notebook.isShared {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct FeedNotebook: Identifiable {
    let id = UUID()
    let title: String
    let owner: String
    let lastModified: Date
    let icon: String
    let color: Color
    let isShared: Bool
} 
