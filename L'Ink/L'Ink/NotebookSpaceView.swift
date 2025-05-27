import SwiftUI
import FirebaseFirestore

// MARK: - Section Header View
struct SectionHeaderView: View {
    let selectedSection: Int
    let onSectionSelected: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onSectionSelected(index)
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(sectionTitle(for: index))
                            .font(.system(size: 16, weight: selectedSection == index ? .semibold : .regular))
                            .foregroundColor(selectedSection == index ? .black : .gray)
                        
                        Rectangle()
                            .fill(selectedSection == index ? Color.black : Color.clear)
                            .frame(width: 30, height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
    }
    
    private func sectionTitle(for index: Int) -> String {
        switch index {
        case 0: return "My Notebooks"
        case 1: return "Shared"
        case 2: return "Favorites"
        default: return ""
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let section: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: sectionEmptyIcon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(sectionEmptyTitle)
                .font(.title2)
                .foregroundColor(.gray)
            Text(sectionEmptyMessage)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var sectionEmptyIcon: String {
        switch section {
        case 0: return "book.closed"
        case 1: return "person.2"
        case 2: return "star"
        default: return "book.closed"
        }
    }
    
    private var sectionEmptyTitle: String {
        switch section {
        case 0: return "No Notebooks"
        case 1: return "No Shared Notebooks"
        case 2: return "No Favorites"
        default: return "No Notebooks"
        }
    }
    
    private var sectionEmptyMessage: String {
        switch section {
        case 0: return "Create your first notebook to get started"
        case 1: return "Shared notebooks will appear here"
        case 2: return "Favorite notebooks will appear here"
        default: return "Create your first notebook to get started"
        }
    }
}

// MARK: - Notebook Space View
struct NotebookSpaceView: View {
    @StateObject private var viewModel = NotebookViewModel()
    @State private var showingNewNotebook = false
    @State private var searchText = ""
    @State private var selectedSection = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isEditMode = false
    @State private var notebookToDelete: Notebook?
    @State private var showingDeleteAlert = false
    
    var filteredNotebooks: [Notebook] {
        let notebooks: [Notebook]
        switch selectedSection {
        case 0: // My Notebooks
            notebooks = viewModel.notebooks.filter { $0.ownerId == viewModel.testUserId }
        case 1: // Shared Notebooks
            notebooks = viewModel.notebooks.filter { $0.isPublic }
        case 2: // Favorites
            notebooks = viewModel.notebooks.filter { $0.isFavorite }
        default:
            notebooks = []
        }
        
        if searchText.isEmpty {
            return notebooks
        } else {
            return notebooks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 0) {
                    SectionHeaderView(selectedSection: selectedSection) { index in
                        selectedSection = index
                    }
                    
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
                
                // Content Section
                if filteredNotebooks.isEmpty {
                    Spacer()
                    EmptyStateView(section: selectedSection)
                    Spacer()
                } else {
                    NotebookScrollView(
                        notebooks: filteredNotebooks,
                        isEditMode: isEditMode,
                        scrollOffset: $scrollOffset,
                        onDelete: { notebook in
                            notebookToDelete = notebook
                            showingDeleteAlert = true
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isEditMode.toggle()
                    }) {
                        Text(isEditMode ? "Done" : "Edit")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewNotebook = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewNotebook) {
                NewNotebookView { title, description, isPublic in
                    viewModel.createNotebook(title: title, isPublic: isPublic, description: description)
                }
            }
            .alert("Delete Notebook", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let notebook = notebookToDelete {
                        viewModel.deleteNotebook(notebook)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this notebook? This action cannot be undone.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.fetchNotebooks()
        }
    }
}

// MARK: - Notebook Scroll View
struct NotebookScrollView: View {
    let notebooks: [Notebook]
    let isEditMode: Bool
    @Binding var scrollOffset: CGFloat
    let onDelete: (Notebook) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GeometryReader { geometry in
                Color.clear.preference(key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).minX)
            }
            .frame(width: 0, height: 0)
            
            HStack(spacing: 20) {
                ForEach(Array(notebooks.enumerated()), id: \.element.id) { index, notebook in
                    if isEditMode {
                        NotebookCard(notebook: notebook, index: index, totalCount: notebooks.count, scrollOffset: scrollOffset)
                            .overlay(
                                Button(action: {
                                    onDelete(notebook)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .padding(8),
                                alignment: .top
                            )
                    } else {
                        NavigationLink(destination: NotebookDetailView(notebook: notebook)) {
                            NotebookCard(notebook: notebook, index: index, totalCount: notebooks.count, scrollOffset: scrollOffset)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct NotebookCard: View {
    let notebook: Notebook
    let index: Int
    let totalCount: Int
    let scrollOffset: CGFloat
    
    private var gradientColors: [Color] {
        let colors: [[Color]] = [
            [Color(hex: "2E7D32"), Color(hex: "43A047")], // Dark green to medium green
            [Color(hex: "388E3C"), Color(hex: "4CAF50")], // Medium green to light green
            [Color(hex: "43A047"), Color(hex: "66BB6A")], // Medium green to lighter green
            [Color(hex: "4CAF50"), Color(hex: "81C784")], // Light green to very light green
            [Color(hex: "66BB6A"), Color(hex: "A5D6A7")]  // Lighter green to mint green
        ]
        // Change color every 50 points of scroll for more frequent changes
        let colorIndex = (abs(Int(scrollOffset)) / 50) % colors.count
        return colors[colorIndex]
    }
    
    var body: some View {
        NavigationLink(destination: NotebookDetailView(notebook: notebook)) {
            // Main notebook container
            HStack(spacing: 0) {
                // Spine
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                gradientColors[0].opacity(0.95),
                                gradientColors[1].opacity(0.85)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 40)
                    .overlay(
                        // Spine text
                        Text(notebook.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 120)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .offset(y: 25)
                    )
                
                // Cover
                ZStack {
                    // Cover background with dynamic gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    gradientColors[0].opacity(0.85),
                                    gradientColors[1].opacity(0.75)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 320, height: 400)
                    
                    // Content
                    VStack {
                        Spacer()
                        
                        // Title
                        Text(notebook.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        Spacer()
                        
                        // Notebook info
                        HStack {
                            if notebook.isPinned {
                                Image(systemName: "pin.fill")
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            if notebook.isPublic {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            Spacer()
                            Text("\(notebook.pages.count) pages")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .frame(width: 360, height: 400)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
    }
}

struct CreateNotebookCard: View {
    @Binding var showingNewNotebook: Bool
    
    var body: some View {
        Button(action: { showingNewNotebook = true }) {
            // Main notebook container
            HStack(spacing: 0) {
                // Spine
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.4),
                                Color.blue.opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 40)
                    .overlay(
                        // Spine text
                        Text("New")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 120)
                            .offset(y: 25)
                    )
                
                // Cover
                ZStack {
                    // Cover background
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.1),
                                    Color.blue.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 320, height: 400)
                        .overlay(
                            Rectangle()
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Content
                    VStack(spacing: 20) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue.opacity(0.8))
                        
                        Text("Create New Notebook")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("Start a new journey")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: 360, height: 400)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search notebooks", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct NewNotebookView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var description = ""
    @State private var isPublic = false
    
    var onCreate: (String, String?, Bool) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notebook Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Settings")) {
                    Toggle("Public Notebook", isOn: $isPublic)
                }
            }
            .navigationTitle("New Notebook")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    onCreate(title, description.isEmpty ? nil : description, isPublic)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
