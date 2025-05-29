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
                    VStack(spacing: 4) {
                        Text(sectionTitle(for: index))
                            .font(.system(size: 16, weight: selectedSection == index ? .semibold : .regular))
                            .foregroundColor(selectedSection == index ? .primary : .gray)
                        
                        Rectangle()
                            .fill(selectedSection == index ? Color.black : Color.clear)
                            .frame(width: 30, height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
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

// MARK: - Notebook Scroll View
struct NotebookScrollView: View {
    let notebooks: [Notebook]
    let isEditMode: Bool
    @Binding var scrollOffset: CGFloat
    let onDelete: (Notebook) -> Void
    @Binding var showingNewNotebook: Bool
    @ObservedObject var viewModel: NotebookViewModel
    
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
                        NotebookCard(viewModel: viewModel, notebook: notebook, index: index, totalCount: notebooks.count, scrollOffset: scrollOffset)
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
                                alignment: .topTrailing
                            )
                    } else {
                        NotebookCard(viewModel: viewModel, notebook: notebook, index: index, totalCount: notebooks.count, scrollOffset: scrollOffset)
                    }
                }
                
                if !isEditMode {
                    CreateNotebookCard(showingNewNotebook: $showingNewNotebook)
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
        case 2: return "heart"
        default: return "book.closed"
        }
    }
    
    private var sectionEmptyTitle: String {
        switch section {
        case 0: return "No notebooks yet"
        case 1: return "No shared notebooks"
        case 2: return "No favorite notebooks"
        default: return "No notebooks"
        }
    }
    
    private var sectionEmptyMessage: String {
        switch section {
        case 0: return "Create your first notebook to get started"
        case 1: return "Notebooks shared with you will appear here"
        case 2: return "Coming Soon..."
        default: return ""
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
            notebooks = viewModel.notebooks.filter { $0.ownerId == viewModel.currentUserid}
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
            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header Section
                    SectionHeaderView(selectedSection: selectedSection) { index in
                        selectedSection = index
                    }
                    
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    
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
                            },
                            showingNewNotebook: $showingNewNotebook,
                            viewModel: viewModel
                        )
                    }
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
            }
            .sheet(isPresented: $showingNewNotebook) {
                NewNotebookView { title, description, isPublic, cover in
                    viewModel.createNotebook(title: title, isPublic: isPublic, description: description, cover: cover)
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

struct NotebookCard: View {
    @ObservedObject var viewModel: NotebookViewModel
    let notebook: Notebook
    let index: Int
    let totalCount: Int
    let scrollOffset: CGFloat
    @State private var showOptions = false
    @State private var navigate = false
    
    // Helper to match spine color to cover
    private func spineColor(for cover: String) -> Color {
        switch cover {
        case "Blue": return Color(hex: "1E4D8B")
        case "Cookbook": return Color(hex: "B7A16A")
        case "Green": return Color(hex: "388E3C")
        case "Grey": return Color(hex: "757575")
        case "Journal": return Color(hex: "A0522D")
        case "Pink": return Color(hex: "D81B60")
        default: return Color.gray
        }
    }
    
    var body: some View {
        ZStack {
            // Invisible NavigationLink triggered by state
            NavigationLink(destination: NotebookDetailView(viewModel: viewModel, notebookId: notebook.id), isActive: $navigate) {
                EmptyView()
            }.hidden()
            // Main notebook container
            HStack(spacing: 0) {
                // Spine
                Rectangle()
                    .fill(spineColor(for: notebook.coverImage))
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
                    Image(notebook.coverImage)
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fit)
                        .frame(width: 320, height: 400)
                        .cornerRadius(8)
                    // Content
                    VStack {
                        Spacer()
                        // Title removed from here
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
            .onTapGesture {
                navigate = true
            }
            .simultaneousGesture(LongPressGesture().onEnded { _ in
                showOptions = true
            })
            .actionSheet(isPresented: $showOptions) {
                ActionSheet(title: Text("Notebook Options"), buttons: [
                    .default(Text("Share Notebook")) {
                        // Share functionality here
                    },
                    .destructive(Text("Delete Notebook")) {
                        // Delete functionality here
                    },
                    .cancel()
                ])
            }
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
    @State private var selectedCover: String = "Blue"
    let coverTemplates = ["Blue", "Cookbook", "Green", "Grey", "Journal", "Pink"]
    var onCreate: (String, String?, Bool, String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                // Cover picker at the top
                Section(header: Text("Choose a Cover")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(coverTemplates, id: \.self) { template in
                                ZStack {
                                    Image(template)
                                        .resizable()
                                        .aspectRatio(3/4, contentMode: .fit)
                                        .frame(width: 80, height: 100)
                                        .cornerRadius(10)
                                        .shadow(radius: selectedCover == template ? 8 : 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedCover == template ? Color.blue : Color.clear, lineWidth: 4)
                                        )
                                        .onTapGesture {
                                            selectedCover = template
                                        }
                                    if selectedCover == template {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .offset(x: 30, y: -40)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
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
                    onCreate(title, description.isEmpty ? nil : description, isPublic, selectedCover)
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
