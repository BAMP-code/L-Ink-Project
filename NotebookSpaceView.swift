//
//  NotebookSpaceView.swift
//  L'Ink
//
//  Created by Daniela on 4/28/25.
//

import SwiftUI

struct NotebookSpaceView: View {
    @State private var notebooks: [Notebook] = [
        Notebook(title: "My First Notebook", pageCount: 12, lastModified: Date(), coverColor: .blue, icon: "book.closed.fill"),
        Notebook(title: "Project Ideas", pageCount: 8, lastModified: Date().addingTimeInterval(-86400), coverColor: .green, icon: "book.fill"),
        Notebook(title: "Daily Journal", pageCount: 30, lastModified: Date().addingTimeInterval(-172800), coverColor: .purple, icon: "text.book.closed.fill")
    ]
    @State private var showingNewNotebook = false
    @State private var searchText = ""
    @State private var selectedNotebook: Notebook?
    @State private var currentPage = 0
    
    var filteredNotebooks: [Notebook] {
        if searchText.isEmpty {
            return notebooks
        } else {
            return notebooks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
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
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No notebooks yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Create your first notebook to get started")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    GeometryReader { geometry in
                        TabView(selection: $currentPage) {
                            ForEach(Array(filteredNotebooks.enumerated()), id: \.element.id) { index, notebook in
                                NavigationLink(destination: NotebookDetailView(notebook: notebook)) {
                                    NotebookCoverCard(notebook: notebook)
                                        .frame(width: geometry.size.width - 40, height: geometry.size.height - 100)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: geometry.size.height - 50)
                    }
                    
                    // Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<filteredNotebooks.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Notebook Space")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewNotebook = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewNotebook) {
                NewNotebookView(onCreate: { newNotebook in
                    notebooks.insert(newNotebook, at: 0)
                    currentPage = 0
                })
            }
        }
    }
}

struct NotebookDetailView: View {
    let notebook: Notebook
    @State private var pages: [NotebookPage] = []
    @State private var isAnimating = false
    @State private var currentRotation: Double = 0
    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Main content
            GeometryReader { geometry in
                TabView {
                    // Cover Page
                    ZStack {
                        // Book spine shadow
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 20)
                            .blur(radius: 5)
                            .offset(x: -geometry.size.width/2 + 10)
                            .opacity(isAnimating ? 1 : 0)
                        
                        // Book cover
                        VStack(spacing: 0) {
                            ZStack {
                                // Main cover
                                RoundedRectangle(cornerRadius: isAnimating ? 0 : 15)
                                    .fill(notebook.coverColor)
                                    .frame(width: geometry.size.width - 40, height: geometry.size.height - 40)
                                    .shadow(radius: isAnimating ? 10 : 5)
                                    .overlay(
                                        // Edge shadow for 3D effect
                                        Rectangle()
                                            .fill(Color.black.opacity(0.2))
                                            .frame(width: 20)
                                            .blur(radius: 5)
                                            .offset(x: -geometry.size.width/2 + 20)
                                            .opacity(isAnimating ? 1 : 0)
                                    )
                                
                                // Cover content
                                VStack(spacing: geometry.size.height * 0.05) {
                                    Spacer()
                                        .frame(height: geometry.size.height * 0.1)
                                    
                                    Image(systemName: notebook.icon)
                                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.2))
                                        .foregroundColor(.white)
                                    
                                    Text(notebook.title)
                                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.08))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                        .minimumScaleFactor(0.5)
                                    
                                    Spacer()
                                    
                                    // Book metadata at bottom
                                    VStack(spacing: 8) {
                                        Text("\(notebook.pageCount) pages")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Text(notebook.lastModified, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.bottom, geometry.size.height * 0.08)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .rotation3DEffect(
                            .degrees(isAnimating ? currentRotation : 0),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.3
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(0)
                    
                    // Content Pages
                    ForEach(pages) { page in
                        NotebookPageView(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            // Navigation Bar (custom)
            VStack {
                HStack {
                    // Back Button
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Notebook Space")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    // Edit Button
                    Button(action: { isEditing.toggle() }) {
                        Text("Edit")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground).opacity(0.8))
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                isAnimating = true
            }
            // Create page-turning effect
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                currentRotation = -5
            }
        }
        .onDisappear {
            isAnimating = false
            currentRotation = 0
        }
        .sheet(isPresented: $isEditing) {
            NotebookEditView(notebook: notebook, pages: $pages)
        }
    }
}

struct NotebookPageView: View {
    let page: NotebookPage
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Page background with shadow
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.white)
                    .frame(width: geometry.size.width - 40, height: geometry.size.height - 40)
                    .shadow(radius: 5)
                
                // Page content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(page.title)
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.06))
                            .fontWeight(.bold)
                            .padding(.top, 30)
                        
                        Text(page.content)
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.04))
                        
                        if let image = page.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                                .frame(maxWidth: geometry.size.width - 80) // Additional padding for images
                        }
                        
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 30)
                }
                .frame(width: geometry.size.width - 40, height: geometry.size.height - 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct NewPageView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var content = ""
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    var onCreate: (NotebookPage) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Page Details")) {
                    TextField("Title", text: $title)
                    TextEditor(text: $content)
                        .frame(height: 200)
                }
                
                Section(header: Text("Image")) {
                    Button(action: { showingImagePicker = true }) {
                        HStack {
                            Image(systemName: "photo")
                            Text(selectedImage == nil ? "Add Image" : "Change Image")
                        }
                    }
                    
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                }
            }
            .navigationTitle("New Page")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    let newPage = NotebookPage(
                        title: title,
                        content: content,
                        image: selectedImage
                    )
                    onCreate(newPage)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.isEmpty)
            )
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
}

struct NotebookPage: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let image: UIImage?
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
            super.init()
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct NotebookCoverCard: View {
    let notebook: Notebook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cover Image
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(notebook.coverColor)
                    .frame(height: 300)
                    .shadow(radius: 5)
                
                VStack {
                    Image(systemName: notebook.icon)
                        .font(.system(size: 70))
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    
                    Text(notebook.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            // Notebook Info
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.blue)
                Text("\(notebook.pageCount) pages")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(notebook.lastModified, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct NewNotebookView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var description = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String = "book.closed.fill"
    
    let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .red]
    let icons: [String] = ["book.closed.fill", "book.fill", "text.book.closed.fill", "book.circle.fill"]
    
    var onCreate: (Notebook) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notebook Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Cover Design")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .blue : .gray)
                                    .frame(width: 40, height: 40)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                Section(header: Text("Settings")) {
                    Toggle("Private Notebook", isOn: .constant(false))
                }
            }
            .navigationTitle("New Notebook")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    let newNotebook = Notebook(
                        title: title,
                        pageCount: 0,
                        lastModified: Date(),
                        coverColor: selectedColor,
                        icon: selectedIcon
                    )
                    onCreate(newNotebook)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

struct Notebook: Identifiable {
    let id = UUID()
    let title: String
    let pageCount: Int
    let lastModified: Date
    let coverColor: Color
    let icon: String
}

struct NotebookEditView: View {
    let notebook: Notebook
    @Binding var pages: [NotebookPage]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Pages")) {
                    ForEach(pages) { page in
                        HStack {
                            Text(page.title)
                            Spacer()
                            Text("\(page.content.prefix(30))...")
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    .onMove { from, to in
                        pages.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { indexSet in
                        pages.remove(atOffsets: indexSet)
                    }
                    
                    Button(action: addNewPage) {
                        Label("Add Page", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Edit Notebook")
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func addNewPage() {
        let newPage = NotebookPage(title: "New Page", content: "", image: nil)
        pages.append(newPage)
    }
} 
