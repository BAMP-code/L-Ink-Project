import SwiftUI

struct NotebookDetailView: View {
    @ObservedObject var viewModel: NotebookViewModel
    let notebookId: String
    
    @State private var selectedPageIndex: Int
    @State private var showingNewPageSheet = false
    @State private var newPageType: PageType = .text
    @State private var rotation: Double = 0
    @State private var isFlipping = false
    @State private var isEditingPage = false
    @State private var myTextBoxes: [(id: UUID, text: String, position: CGPoint)] = []
    @State private var myImages: [(id: UUID, image: UIImage, position: CGPoint, imageUrl: String?)] = []
    @State private var myShowImageInsert = false
    @State private var showSystemImagePicker = false
    @State private var imageToAdd: UIImage? = nil
    @State private var selectedTextBoxID: UUID? = nil
    @State private var selectedImageID: UUID? = nil
    @State private var editingTextBoxID: UUID? = nil
    
    init(viewModel: NotebookViewModel, notebookId: String) {
        self.viewModel = viewModel
        self.notebookId = notebookId
        // Find the notebook and initialize selectedPageIndex
        let initialNotebook = viewModel.notebooks.first(where: { $0.id == notebookId })
        _selectedPageIndex = State(initialValue: initialNotebook?.lastViewedPageIndex ?? 0)
    }
    
    // Computed property to access the current notebook from the view model
    private var notebook: Notebook? {
        viewModel.notebooks.first(where: { $0.id == notebookId })
    }
    
    // Computed property for the editing view
    private var editingPageView: some View {
        ZStack(alignment: .center) {
            PageView(page: notebook!.pages[selectedPageIndex], showWelcome: false, showCanvasElements: false)
                .rotation3DEffect(
                    .degrees(0), // No rotation in edit mode
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.5
                )
                .opacity(1)
                .zIndex(0)
            if !myTextBoxes.isEmpty || !myImages.isEmpty {
                ForEach($myTextBoxes, id: \.id) { $box in
                    MyCanvasTextBox(
                        text: $box.text,
                        position: $box.position,
                        selected: selectedTextBoxID == box.id,
                        isEditing: Binding(
                            get: { editingTextBoxID == box.id },
                            set: { newValue in editingTextBoxID = newValue ? box.id : nil }
                        ),
                        onSelect: {
                            selectedTextBoxID = box.id
                            selectedImageID = nil
                            editingTextBoxID = box.id
                        },
                        onDelete: { myTextBoxes.removeAll { $0.id == box.id } }
                    )
                    .zIndex(3)
                }
                ForEach($myImages, id: \.id) { $img in
                    MyCanvasImage(
                        image: img.image, // MyCanvasImage still takes UIImage
                        position: $img.position,
                        selected: selectedImageID == img.id,
                        onSelect: {
                            selectedImageID = img.id
                            selectedTextBoxID = nil
                            editingTextBoxID = nil
                        },
                        onDelete: { myImages.removeAll { $0.id == img.id } } // Delete from state variable
                    )
                    .zIndex(3)
                }
            }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if editingTextBoxID != nil {
                        editingTextBoxID = nil
                    } else {
                        selectedTextBoxID = nil
                        selectedImageID = nil
                    }
                }
        }
        .frame(width: 360, height: 400)
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // Computed property for the reading view
    private var readingPageView: some View {
        ZStack(alignment: .center) {
            // Page background and lines (copied from PageView)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 40)
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 320, height: 400)
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
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
            }
            .frame(height: 400)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

            // Render overlays from the model (text boxes and images)
            if let textBoxes = notebook!.pages[selectedPageIndex].textBoxes {
                ForEach(textBoxes) { box in
                    Text(box.text)
                        .font(.body)
                        .frame(minWidth: 60, maxWidth: 180, minHeight: 32, alignment: .topLeading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                        .background(Color.clear)
                        .cornerRadius(8)
                        .position(
                            x: box.position.x.isFinite ? box.position.x : 100,
                            y: box.position.y.isFinite ? box.position.y : 100
                        )
                }
            }
            if let images = notebook!.pages[selectedPageIndex].images {
                ForEach(images) { img in
                    // Use CanvasImageView to load and display image from URL
                    CanvasImageView(imageModel: img)
                }
            }
        }
        .frame(width: 360, height: 400)
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.5
        )
        .opacity(1)
    }
    
    var body: some View {
        // Ensure notebook exists before rendering the body
        if let notebook = notebook {
            VStack(spacing: 0) {
                // Reserve space for edit menu in both modes
                if isEditingPage {
                    HStack(spacing: 32) {
                        Button(action: { addMyTextBox() }) {
                            Image(systemName: "textformat")
                                .font(.title2)
                        }
                        Button(action: { showSystemImagePicker = true }) {
                            Image(systemName: "photo")
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    Spacer().frame(height: 60)
                }
                // 3D Notebook View or Canvas
                ZStack {
                    if isEditingPage {
                        editingPageView
                    } else {
                        readingPageView
                    }
                }
                .frame(height: 500)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isFlipping && !isEditingPage {
                                rotation = Double(value.translation.width / 2)
                            }
                        }
                        .onEnded { value in
                            if !isEditingPage {
                            if value.translation.width < -100 && selectedPageIndex < notebook.pages.count - 1 {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    rotation = -180
                                    isFlipping = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    selectedPageIndex += 1
                                    Task {
                                        await saveLastViewedPage()
                                    }
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
                                    Task {
                                        await saveLastViewedPage()
                                    }
                                    rotation = 0
                                    isFlipping = false
                                }
                            } else {
                                withAnimation {
                                    rotation = 0
                                    }
                                }
                            }
                        }
                )
                // Minimal page indicator between notebook and Edit button
                Spacer().frame(height: 16)
                Text("Page \(selectedPageIndex + 1) of \(notebook.pages.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)
                    .textSelection(.enabled)
                    .tint(.blue)
                // Big Edit button
                Button(action: {
                    if isEditingPage {
                        Task {
                            await saveCanvasToPage()
                        }
                        selectedTextBoxID = nil
                        selectedImageID = nil
                        editingTextBoxID = nil
                    } else {
                        loadCanvasFromPage()
                    }
                    isEditingPage.toggle()
                }) {
                    Text(isEditingPage ? "Done" : "Edit")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                .padding()
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle(notebook.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewPageSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showingNewPageSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Page Type")) {
                            Picker("Type", selection: $newPageType) {
                                Text("Text").tag(PageType.text)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .navigationTitle("New Page")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingNewPageSheet = false
                        },
                        trailing: Button("Add") {
                            viewModel.addPage(to: notebook, type: newPageType)
                            selectedPageIndex = notebook.pages.count - 1
                            showingNewPageSheet = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showSystemImagePicker) {
                MySystemImagePicker { image in
                    if let image = image {
                        myImages.append((UUID(), image, CGPoint(x: 200, y: 200), nil))
                    }
                    showSystemImagePicker = false
                }
            }
            .onChange(of: selectedPageIndex) { _, _ in
                Task {
                    await loadCanvasFromPage()
                }
            }
        }
    }
    
    private func saveLastViewedPage() async {
        var updatedNotebook = notebook!
        updatedNotebook.lastViewedPageIndex = selectedPageIndex
        viewModel.updateNotebook(updatedNotebook)
    }

    private func saveCanvasToPage() async {
        let textBoxModels: [CanvasTextBoxModel] = myTextBoxes.map { box in
            CanvasTextBoxModel(
                id: box.id,
                text: box.text,
                position: CGPointCodable(box.position)
            )
        }

        var uploadedImageModels: [CanvasImageModel] = []
        for index in myImages.indices {
            var img = myImages[index]
            // If image hasn't been uploaded yet
            if img.imageUrl == nil, let imageData = img.image.pngData() {
                let storagePath = "notebook_images/\(notebook!.id)/\(notebook!.pages[selectedPageIndex].id)/\(img.id).jpg"
                do {
                    let downloadURL = try await StorageService.shared.uploadImage(img.image, path: storagePath)
                    img.imageUrl = downloadURL
                    myImages[index] = img // Update the state variable
                } catch {
                    print("Error uploading image: \(error)")
                    // Handle error, maybe skip this image or show an alert
                    continue // Skip to the next image if upload fails
                }
            }
            
            // Create CanvasImageModel with the URL (either new or existing)
            if let imageUrl = img.imageUrl {
                 uploadedImageModels.append(CanvasImageModel(
                     id: img.id,
                     imageData: nil, // Data is not saved in Firestore
                     imageUrl: imageUrl,
                     position: CGPointCodable(img.position)
                 ))
            }
        }

        let imageModels = uploadedImageModels

        var updatedPage = notebook!.pages[selectedPageIndex]
        updatedPage.textBoxes = textBoxModels
        updatedPage.images = imageModels
        updatedPage.updatedAt = Date()
        var updatedNotebook = notebook!
        updatedNotebook.pages[selectedPageIndex] = updatedPage
        updatedNotebook.updatedAt = Date()
        Task {
            viewModel.updateNotebook(updatedNotebook)
        }
    }

    private func loadCanvasFromPage() {
        guard let notebook = notebook else { return }
        let page = notebook.pages[selectedPageIndex]

        myTextBoxes = page.textBoxes?.map { box in
            (box.id, box.text, box.position.cgPoint)
        } ?? []

        // Load images from URLs
        myImages = [] // Clear existing images
        Task {
            await loadImagesFromURLs(page.images)
        }
    }

    private func loadImagesFromURLs(_ imageModels: [CanvasImageModel]?) async {
        guard let imageModels = imageModels else { return }

        var loadedImages: [(id: UUID, image: UIImage, position: CGPoint, imageUrl: String?)] = []
        for model in imageModels {
            if let imageUrlString = model.imageUrl, let imageUrl = URL(string: imageUrlString) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: imageUrl)
                    if let image = UIImage(data: data) {
                        loadedImages.append((id: model.id, image: image, position: model.position.cgPoint, imageUrl: imageUrlString))
                    }
                } catch {
                    print("Error loading image from URL \(imageUrlString): \(error)")
                    // Handle error loading image
                }
            }
        }
        // Update the state variable on the main actor
        await MainActor.run {
            myImages = loadedImages
        }
    }

    private func addMyTextBox() {
        myTextBoxes.append((UUID(), "New Text", CGPoint(x: 150, y: 150)))
    }

    // Function to add image to myImages after selection
    private func addMyImage(_ image: UIImage) {
        myImages.append((id: UUID(), image: image, position: CGPoint(x: 200, y: 200), imageUrl: nil))
    }
}

// UIKit-based image picker for adding images
struct MySystemImagePicker: UIViewControllerRepresentable {
    var completion: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: MySystemImagePicker
        init(_ parent: MySystemImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                self.parent.completion(image)
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
        }
    }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

struct NotebookCover: View {
    let notebook: Notebook
    
    var body: some View {
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
                    Text(notebook.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue.opacity(0.8))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .offset(y: 25)
                )
            
            // Cover
            ZStack {
                // Cover background with shadow effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 320, height: 400)
                
                // Content
                VStack(spacing: 20) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text(notebook.title)
                        .font(.title)
                        .bold()
                        .foregroundColor(.blue.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let description = notebook.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.blue.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
            }
        }
        .frame(height: 400)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .frame(width: 360, height: 400)
    }
}

struct PageView: View {
    let page: Page
    var showWelcome: Bool = false
    var showCanvasElements: Bool = true
    
    var body: some View {
        ZStack {
            // Main page container
            HStack(spacing: 0) {
                // Spine shadow
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 40)
                
                // Page content
                ZStack {
                    // Page background
                    Rectangle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 320, height: 400)
                    
                    // Page lines
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
                    
                    // Content
                    if page.type == .text {
                        Text(page.content)
                            .font(.body)
                            .foregroundColor(.black.opacity(0.8))
                            .padding()
                    }
                    
                    // Display saved text boxes
                    if showCanvasElements, let textBoxes = page.textBoxes {
                        ForEach(textBoxes) { box in
                            Text(box.text)
                                .font(.body)
                                .frame(minWidth: 60, maxWidth: 180, minHeight: 32, alignment: .topLeading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(8)
                                .background(Color.clear)
                                .cornerRadius(8)
                                .position(
                                    x: box.position.x.isFinite ? box.position.x : 100,
                                    y: box.position.y.isFinite ? box.position.y : 100
                                )
                        }
                    }
                    
                    // Display saved images
                    if showCanvasElements, let images = page.images {
                        ForEach(images) { img in
                            // Use a helper view to load and display image from URL
                            CanvasImageView(imageModel: img)
                        }
                    }
                }
            }
            .frame(height: 400)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .frame(width: 360, height: 400)
    }
}

struct PageThumbnail: View {
    let page: Page
    let isSelected: Bool
    
    var body: some View {
        VStack {
            Image(systemName: page.type == .text ? "doc.text" : "pencil.tip")
                .font(.title2)
            Text("Page \(page.order + 1)")
                .font(.caption)
        }
        .frame(width: 60, height: 80)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct PageContentView: View {
    let page: Page
    let onUpdate: (String) -> Void
    @State private var textContent: String
    
    init(page: Page, onUpdate: @escaping (String) -> Void) {
        self.page = page
        self.onUpdate = onUpdate
        _textContent = State(initialValue: page.content)
    }
    
    var body: some View {
        TextEditor(text: $textContent)
            .onChange(of: textContent) { oldValue, newValue in
                onUpdate(newValue)
            }
            .padding()
    }
}

struct MyCanvasTextBox: View {
    @Binding var text: String
    @Binding var position: CGPoint
    var selected: Bool
    @Binding var isEditing: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    @GestureState private var dragOffset: CGSize = .zero
    @State private var isMoving: Bool = false
    @State private var dragStart: CGPoint? = nil
    @State private var showDeleteAlert = false

    init(text: Binding<String>, position: Binding<CGPoint>, selected: Bool, isEditing: Binding<Bool>, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self._text = text
        self._position = position
        self.selected = selected
        self._isEditing = isEditing
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if selected && isEditing {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(minWidth: 60, maxWidth: 180, minHeight: 32)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .cornerRadius(8)
                    .onTapGesture { onSelect() }
                    .foregroundColor(.black)
            } else {
                Text(text.isEmpty ? " " : text)
                    .font(.body)
                    .frame(minWidth: 60, maxWidth: 180, minHeight: 32, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .onTapGesture {
                        onSelect()
                        isEditing = true
                    }
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation
                            }
                            .onChanged { value in
                                if dragStart == nil { dragStart = position }
                                position = CGPoint(x: dragStart!.x + value.translation.width, y: dragStart!.y + value.translation.height)
                                onSelect()
                            }
                            .onEnded { value in
                                position.x += value.translation.width
                                position.y += value.translation.height
                                dragStart = nil
                            }
                    )
                    .foregroundColor(.black)
            }
            if selected {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .offset(x: 10, y: -10)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundColor(selected ? Color.blue.opacity(0.7) : .clear)
        )
        .position(
            x: position.x.isFinite ? position.x : 100,
            y: position.y.isFinite ? position.y : 100
        )
        .onLongPressGesture {
            showDeleteAlert = true
        }
        .alert("Delete this text box?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }
}

struct MyCanvasImage: View {
    let image: UIImage
    @Binding var position: CGPoint
    var selected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    @GestureState private var dragOffset: CGSize = .zero
    @State private var isMoving: Bool = false
    @State private var dragStart: CGPoint? = nil
    @State private var showDeleteAlert = false

    init(image: UIImage, position: Binding<CGPoint>, selected: Bool, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.image = image
        self._position = position
        self.selected = selected
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .frame(width: 100, height: 100)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundColor(selected ? Color.blue.opacity(0.7) : .clear)
                )
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onChanged { _ in onSelect() }
                        .onEnded { value in
                            position.x += value.translation.width
                            position.y += value.translation.height
                        }
                )
            if selected {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .offset(x: 10, y: -10)
            }
        }
        .position(
            x: position.x.isFinite ? position.x : 100,
            y: position.y.isFinite ? position.y : 100
        )
        .onTapGesture { onSelect() }
        .onLongPressGesture {
            showDeleteAlert = true
        }
        .alert("Delete this image?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// Add a helper view to load and display images from URL
struct CanvasImageView: View {
    let imageModel: CanvasImageModel
    @State private var loadedImage: UIImage? = nil

    var body: some View {
        Group {
            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
            } else {
                // Placeholder while loading or if loading fails
                ProgressView()
            }
        }
        .position(
            x: imageModel.position.x.isFinite ? imageModel.position.x : 100,
            y: imageModel.position.y.isFinite ? imageModel.position.y : 100
        )
        .task { // Use .task to load image when view appears
            if loadedImage == nil, let imageUrlString = imageModel.imageUrl, let imageUrl = URL(string: imageUrlString) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: imageUrl)
                    if let image = UIImage(data: data) {
                        loadedImage = image
                    }
                } catch {
                    print("Error loading image from URL \(imageUrlString): \(error)")
                    // Handle error loading image
                }
            }
        }
    }
}




