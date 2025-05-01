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
            VStack {
                // Segmented Control
                Picker("Feed Type", selection: $selectedTab) {
                    Text("Recent").tag(0)
                    Text("Shared").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                if selectedTab == 0 {
                    RecentNotebooksList(notebooks: recentNotebooks)
                } else {
                    SharedNotebooksList(notebooks: sharedNotebooks)
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
