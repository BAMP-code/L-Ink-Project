//
//  NotebookFeedView.swift
//  L'Ink
//
//  Created by Daniela on 4/28/25.
//

import SwiftUI

class FeedViewModel: ObservableObject {
    @Published var recentNotebooks: [FeedNotebook] = []
    @Published var sharedNotebooks: [FeedNotebook] = []
    @Published var searchText: String = ""
    
    init() {
        loadMockData()
    }
    
    func loadMockData() {
        // Mock data for recent notebooks
        recentNotebooks = [
            FeedNotebook(
                title: "Project Planning",
                owner: "John Doe",
                lastModified: Date().addingTimeInterval(-3600),
                icon: "doc.text",
                color: .blue,
                isShared: false
            ),
            FeedNotebook(
                title: "Meeting Notes",
                owner: "Jane Smith",
                lastModified: Date().addingTimeInterval(-7200),
                icon: "note.text",
                color: .green,
                isShared: true
            )
        ]
        
        // Mock data for shared notebooks
        sharedNotebooks = [
            FeedNotebook(
                title: "Team Brainstorm",
                owner: "Alex Johnson",
                lastModified: Date().addingTimeInterval(-10800),
                icon: "lightbulb",
                color: .orange,
                isShared: true
            ),
            FeedNotebook(
                title: "Research Notes",
                owner: "Sarah Wilson",
                lastModified: Date().addingTimeInterval(-14400),
                icon: "book",
                color: .purple,
                isShared: true
            )
        ]
    }
    
    func refreshData() {
        // In a real app, this would fetch data from your backend
        loadMockData()
    }
    
    var filteredRecentNotebooks: [FeedNotebook] {
        if searchText.isEmpty {
            return recentNotebooks
        }
        return recentNotebooks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredSharedNotebooks: [FeedNotebook] {
        if searchText.isEmpty {
            return sharedNotebooks
        }
        return sharedNotebooks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

struct NotebookFeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedTab = 0
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                FeedSearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                
                // Segmented Control
                Picker("Feed Type", selection: $selectedTab) {
                    Text("Recent").tag(0)
                    Text("Shared").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                if selectedTab == 0 {
                    RecentNotebooksList(
                        notebooks: viewModel.filteredRecentNotebooks,
                        isRefreshing: $isRefreshing,
                        onRefresh: {
                            refreshData()
                        }
                    )
                } else {
                    SharedNotebooksList(
                        notebooks: viewModel.filteredSharedNotebooks,
                        isRefreshing: $isRefreshing,
                        onRefresh: {
                            refreshData()
                        }
                    )
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "bell")
                    }
                }
            }
        }
    }
    
    private func refreshData() {
        isRefreshing = true
        viewModel.refreshData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRefreshing = false
        }
    }
}

struct FeedSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search notebooks...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct RecentNotebooksList: View {
    let notebooks: [FeedNotebook]
    @Binding var isRefreshing: Bool
    let onRefresh: () -> Void
    
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
                    NavigationLink(destination: FeedNotebookDetailView(notebook: notebook)) {
                        FeedNotebookRow(notebook: notebook)
                    }
                }
            }
            .refreshable {
                onRefresh()
            }
        }
    }
}

struct SharedNotebooksList: View {
    let notebooks: [FeedNotebook]
    @Binding var isRefreshing: Bool
    let onRefresh: () -> Void
    
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
                    NavigationLink(destination: FeedNotebookDetailView(notebook: notebook)) {
                        FeedNotebookRow(notebook: notebook)
                    }
                }
            }
            .refreshable {
                onRefresh()
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

struct FeedNotebookDetailView: View {
    let notebook: FeedNotebook
    
    var body: some View {
        VStack {
            Text("Notebook Details")
                .font(.title)
            Text(notebook.title)
                .font(.headline)
            Text("Owner: \(notebook.owner)")
            Text("Last Modified: \(notebook.lastModified, style: .relative)")
        }
        .padding()
    }
} 
