import SwiftUI

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

struct NotebookDetailView: View {
    @ObservedObject var viewModel: NotebookViewModel
    let notebookId: String
    
    @State private var selectedPageIndex: Int
    @State private var showingNewPageSheet = false
    @State private var newPageType: PageType = .text
    @State private var rotation: Double = 0
    @State private var isFlipping = false
    @State private var isFlipped = false
    @State private var isEditingPage = false
    @State private var myTextBoxes: [(id: UUID, text: String, position: CGPoint)] = []
    @State private var myImages: [(id: UUID, image: UIImage, position: CGPoint, imageURL: URL?)] = []
    @State private var myShowImageInsert = false
    @State private var showSystemImagePicker = false
    @State private var imageToAdd: UIImage? = nil
    @State private var selectedElementId: UUID? = nil
    @State private var editingTextBoxId: UUID? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var isMoving: Bool = false
    @State private var initialPosition: CGPoint? = nil
    @State private var showDeleteAlert = false
    @State private var currentTranslation: CGSize = .zero
    @GestureState private var dragAmount: CGSize = .zero
    @State private var textBoxSizes: [UUID: CGSize] = [:]
    @State private var imageSizes: [UUID: CGSize] = [:]
    @State private var isResizing: Bool = false
    @State private var resizeStartSize: CGSize = .zero
    @State private var resizeStartPoint: CGPoint = .zero
    
    init(viewModel: NotebookViewModel, notebookId: String) {
        self.viewModel = viewModel
        self.notebookId = notebookId
        let initialNotebook = viewModel.notebooks.first(where: { $0.id == notebookId })
        _selectedPageIndex = State(initialValue: initialNotebook?.lastViewedPageIndex ?? 0)
    }
    
    private var notebook: Notebook? {
        viewModel.notebooks.first(where: { $0.id == notebookId })
    }
    
    private var editingPageView: some View {
        GeometryReader { geometry in
            ZStack {
                // Base page view for background and lines
                PageView(page: notebook!.pages[selectedPageIndex], showWelcome: false, showCanvasElements: false)
                    .onTapGesture {
                        // Deselect all elements when tapping the page
                        selectedElementId = nil
                        editingTextBoxId = nil
                    }
                
                // Canvas elements container
                ZStack {
                    // Text boxes
                    ForEach(myTextBoxes, id: \.id) { box in
                        EditableTextBoxView(
                            box: box,
                            isEditing: editingTextBoxId == box.id,
                            isSelected: selectedElementId == box.id,
                            size: textBoxSizes[box.id] ?? CGSize(width: 200, height: 100),
                            onTextChange: { newText in
                                if let index = myTextBoxes.firstIndex(where: { $0.id == box.id }) {
                                    myTextBoxes[index].text = newText
                                }
                            },
                            onDelete: {
                                myTextBoxes.removeAll { $0.id == box.id }
                                textBoxSizes.removeValue(forKey: box.id)
                                if selectedElementId == box.id {
                                    selectedElementId = nil
                                }
                            },
                            onTap: {
                                selectedElementId = box.id
                                editingTextBoxId = box.id
                            },
                            onDrag: { newPosition in
                                if let index = myTextBoxes.firstIndex(where: { $0.id == box.id }) {
                                    myTextBoxes[index].position = newPosition
                                }
                            },
                            onResize: { newSize in
                                textBoxSizes[box.id] = newSize
                            }
                        )
                    }
                    
                    // Images
                    ForEach(myImages, id: \.id) { img in
                        EditableImageView(
                            img: img,
                            isSelected: selectedElementId == img.id,
                            size: imageSizes[img.id] ?? CGSize(width: 200, height: 200),
                            onDelete: {
                                myImages.removeAll { $0.id == img.id }
                                imageSizes.removeValue(forKey: img.id)
                                if selectedElementId == img.id {
                                    selectedElementId = nil
                                }
                            },
                            onTap: {
                                selectedElementId = img.id
                            },
                            onDrag: { newPosition in
                                if let index = myImages.firstIndex(where: { $0.id == img.id }) {
                                    myImages[index].position = newPosition
                                }
                            },
                            onResize: { newSize in
                                imageSizes[img.id] = newSize
                            }
                        )
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
    
    private var readingPageView: some View {
        GeometryReader { geometry in
            ZStack {
                // Base page view
                PageView(page: notebook!.pages[selectedPageIndex], showWelcome: false, showCanvasElements: false)
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.5
                    )
                
                // Canvas elements container
                ZStack {
                    // Text boxes
                    ForEach(myTextBoxes, id: \.id) { box in
                        Text(box.text)
                            .font(.body)
                            .frame(
                                width: textBoxSizes[box.id]?.width ?? 180,
                                height: textBoxSizes[box.id]?.height ?? 100,
                                alignment: .topLeading
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(8)
                            .background(Color.clear)
                            .cornerRadius(8)
                            .position(box.position)
                    }
                    
                    // Images
                    ForEach(myImages, id: \.id) { img in
                        Image(uiImage: img.image)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: imageSizes[img.id]?.width ?? 200,
                                height: imageSizes[img.id]?.height ?? 200
                            )
                            .position(img.position)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.5
                )
            }
        }
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
                        selectedElementId = nil
                        editingTextBoxId = nil
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
            .onAppear {
                loadCanvasFromPage()
            }
        }
    }
    
    private func saveLastViewedPage() async {
        var updatedNotebook = notebook!
        updatedNotebook.lastViewedPageIndex = selectedPageIndex
        viewModel.updateNotebook(updatedNotebook)
    }

    private func saveCanvasToPage() async {
        guard let notebook = notebook else {
            print("❌ saveCanvasToPage: Notebook is nil. Cannot save.")
            return
        }

        // Ensure selectedPageIndex is valid
        guard selectedPageIndex >= 0 && selectedPageIndex < notebook.pages.count else {
            print("❌ saveCanvasToPage: selectedPageIndex \(selectedPageIndex) is out of bounds for pages array with count \(notebook.pages.count).")
            return
        }

        print("✅ saveCanvasToPage: Saving canvas data for page \(selectedPageIndex)...")
        print("   myTextBoxes count: \(myTextBoxes.count)")
        print("   myImages count: \(myImages.count)")

        let textBoxModels: [CanvasTextBoxModel] = myTextBoxes.map { box in
            let size = textBoxSizes[box.id] ?? CGSize(width: 200, height: 100)
            print("   Saving text box \(box.id) with size: \(size)")
            return CanvasTextBoxModel(
                id: box.id,
                text: box.text,
                position: CGPointCodable(box.position),
                size: CGSizeCodable(size)
            )
        }
        print("   Created \(textBoxModels.count) textBoxModels.")

        var uploadedImageModels: [CanvasImageModel] = []
        for index in myImages.indices {
            var img = myImages[index]
            print("   Processing image \(img.id), URL: \(img.imageURL?.absoluteString ?? "nil")")
            // If image hasn't been uploaded yet
            if img.imageURL == nil, let imageData = img.image.pngData() {
                let storagePath = "notebook_images/\(notebook.id)/\(notebook.pages[selectedPageIndex].id)/\(img.id).jpg"
                print("   Image \(img.id) not uploaded yet. Uploading to \(storagePath)...")
                do {
                    let downloadURL = try await StorageService.shared.uploadImage(img.image, path: storagePath)
                    img.imageURL = URL(string: downloadURL)
                    myImages[index] = img // Update the state variable
                    print("   Upload successful for image \(img.id). URL: \(downloadURL)")
                } catch {
                    print("❌ Error uploading image \(img.id): \(error)")
                    continue
                }
            }

            // Create CanvasImageModel with the URL (either new or existing)
            if let imageURL = img.imageURL {
                let size = imageSizes[img.id] ?? CGSize(width: 200, height: 200)
                print("   Saving image \(img.id) with size: \(size)")
                uploadedImageModels.append(CanvasImageModel(
                    id: img.id,
                    imageData: nil,
                    imageUrl: imageURL.absoluteString,
                    position: CGPointCodable(img.position),
                    size: CGSizeCodable(size)
                ))
                print("   Added CanvasImageModel for image \(img.id) with URL \(imageURL.absoluteString)")
            } else {
                print("   Skipping image \(img.id) due to missing URL after upload attempt.")
            }
        }

        let imageModels = uploadedImageModels
        print("   Created \(imageModels.count) imageModels.")

        var updatedPage = notebook.pages[selectedPageIndex]
        updatedPage.textBoxes = textBoxModels
        updatedPage.images = imageModels
        updatedPage.updatedAt = Date()
        print("   Updated page \(selectedPageIndex) with \(updatedPage.textBoxes?.count ?? 0) text boxes and \(updatedPage.images?.count ?? 0) images.")

        var updatedNotebook = notebook
        updatedNotebook.pages[selectedPageIndex] = updatedPage
        updatedNotebook.updatedAt = Date()
        print("   Updated notebook model. Saving to Firestore...")

        Task {
            viewModel.updateNotebook(updatedNotebook)
            print("   viewModel.updateNotebook called.")
        }
        print("✅ saveCanvasToPage: Finished.")
    }

    private func loadCanvasFromPage() {
        guard let notebook = notebook else { return }
        let page = notebook.pages[selectedPageIndex]
        
        // Load text boxes and their sizes
        myTextBoxes = page.textBoxes?.map { box in
            (id: box.id, text: box.text, position: box.position.cgPoint)
        } ?? []
        
        textBoxSizes = Dictionary(uniqueKeysWithValues: page.textBoxes?.map { box in
            (box.id, box.size?.cgSize ?? CGSize(width: 200, height: 100))
        } ?? [])
        
        // Load images and their sizes
        myImages = page.images?.compactMap { img in
            if let imageUrl = img.imageUrl,
               let url = URL(string: imageUrl) {
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                if let index = myImages.firstIndex(where: { $0.id == img.id }) {
                                    myImages[index].image = image
                                }
                            }
                        }
                    } catch {
                        print("Error loading image: \(error)")
                    }
                }
                return (id: img.id, image: UIImage(), position: img.position.cgPoint, imageURL: url)
            }
            return nil
        } ?? []
        
        imageSizes = Dictionary(uniqueKeysWithValues: page.images?.map { img in
            (img.id, img.size?.cgSize ?? CGSize(width: 200, height: 200))
        } ?? [])
    }

    private func addMyTextBox() {
        myTextBoxes.append((UUID(), "New Text", CGPoint(x: 150, y: 150)))
    }

    // Function to add image to myImages after selection
    private func addMyImage(_ image: UIImage) {
        myImages.append((id: UUID(), image: image, position: CGPoint(x: 200, y: 200), imageURL: nil))
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

// MARK: - UIKit Canvas Integration

struct CanvasKitView: UIViewRepresentable {
    @Binding var textBoxes: [(id: UUID, text: String, position: CGPoint)]
    @Binding var images: [(id: UUID, image: UIImage, position: CGPoint, imageUrl: String?)]
    @Binding var selectedElementId: UUID?
    
    // Closure to report position changes back to SwiftUI
    var onTextBoxPositionChanged: (UUID, CGPoint) -> Void
    var onImagePositionChanged: (UUID, CGPoint) -> Void
    var onTextBoxDeleted: (UUID) -> Void
    var onImageDeleted: (UUID) -> Void
    var onElementSelected: (UUID?, UUID?) -> Void // Reports which element is selected
    
    func makeUIView(context: Context) -> CanvasView {
        let canvasView = CanvasView()
        canvasView.delegate = context.coordinator // Set the delegate
        return canvasView
    }
    
    func updateUIView(_ uiView: CanvasView, context: Context) {
        // Update the UIKit view with the latest data from SwiftUI
        uiView.updateCanvasElements(textBoxes: textBoxes, images: images, selectedElementId: selectedElementId)
    }
    
    // Create a Coordinator to facilitate communication from UIKit to SwiftUI
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CanvasViewDelegate {
        var parent: CanvasKitView
        
        init(_ parent: CanvasKitView) {
            self.parent = parent
        }
        
        func canvasElementDidMove(id: UUID, newPosition: CGPoint, elementType: CanvasElementType) {
            // Report the new position back to the SwiftUI parent view
            switch elementType {
            case .textBox:
                parent.onTextBoxPositionChanged(id, newPosition)
            case .image:
                parent.onImagePositionChanged(id, newPosition)
            }
        }
        
        func canvasElementDidSelect(textBoxId: UUID?, imageId: UUID?) {
            // Report the selected element back to the SwiftUI parent view
            parent.onElementSelected(textBoxId, imageId)
        }
        
        func canvasElementDidDelete(id: UUID, elementType: CanvasElementType) {
             // Report deletion back to the SwiftUI parent
             switch elementType {
             case .textBox:
                 parent.onTextBoxDeleted(id)
             case .image:
                 parent.onImageDeleted(id)
             }
         }
    }
}

// Protocol for the delegate
protocol CanvasViewDelegate: AnyObject {
    func canvasElementDidMove(id: UUID, newPosition: CGPoint, elementType: CanvasElementType)
    func canvasElementDidSelect(textBoxId: UUID?, imageId: UUID?)
    func canvasElementDidDelete(id: UUID, elementType: CanvasElementType)
}

enum CanvasElementType {
    case textBox
    case image
}

class CanvasView: UIView, UIGestureRecognizerDelegate {
    weak var delegate: CanvasViewDelegate? // Delegate to communicate back to SwiftUI
    
    private var textBoxViews: [UUID: UITextView] = [:]
    private var imageViewViews: [UUID: UIImageView] = [:]
    private var borderLayers: [UUID: CAShapeLayer] = [:] // Store border layers
    
    // Cache element data to detect changes in updateCanvasElements
    private var currentTextBoxData: [UUID: (text: String, position: CGPoint)] = [:]
    private var currentImageData: [UUID: (image: UIImage, position: CGPoint, imageUrl: String?)] = [:]
    private var currentSelectedElementId: UUID? = nil

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Basic view setup, like background color
        backgroundColor = .clear // Or a canvas color
        isUserInteractionEnabled = true // Ensure the view can receive touches
    }
    
    private func updateBorder(for view: UIView, id: UUID, isSelected: Bool) {
        // Remove existing border layer if any
        borderLayers[id]?.removeFromSuperlayer()
        
        if isSelected {
            let borderLayer = CAShapeLayer()
            borderLayer.frame = view.bounds
            borderLayer.path = UIBezierPath(roundedRect: view.bounds, cornerRadius: 8.0).cgPath
            borderLayer.fillColor = nil
            borderLayer.strokeColor = UIColor.blue.cgColor
            borderLayer.lineWidth = 2.0
            borderLayer.lineDashPattern = [6, 6]
            view.layer.addSublayer(borderLayer)
            borderLayers[id] = borderLayer
        }
    }
    
    func updateCanvasElements(textBoxes: [(id: UUID, text: String, position: CGPoint)], images: [(id: UUID, image: UIImage, position: CGPoint, imageUrl: String?)], selectedElementId: UUID?) {
        // 1. Remove views that are no longer in the data
        for (id, view) in textBoxViews where !textBoxes.contains(where: { $0.id == id }) {
            view.removeFromSuperview()
            textBoxViews.removeValue(forKey: id)
            currentTextBoxData.removeValue(forKey: id)
            borderLayers[id]?.removeFromSuperlayer()
            borderLayers.removeValue(forKey: id)
        }
        for (id, view) in imageViewViews where !images.contains(where: { $0.id == id }) {
            view.removeFromSuperview()
            imageViewViews.removeValue(forKey: id)
            currentImageData.removeValue(forKey: id)
            borderLayers[id]?.removeFromSuperlayer()
            borderLayers.removeValue(forKey: id)
        }
        
        // 2. Update or Add text box views
        for textBoxData in textBoxes {
            if let existingView = textBoxViews[textBoxData.id] {
                // Update existing view if data changed
                if currentTextBoxData[textBoxData.id]?.text != textBoxData.text || currentTextBoxData[textBoxData.id]?.position != textBoxData.position {
                     existingView.text = textBoxData.text
                     currentTextBoxData[textBoxData.id] = (textBoxData.text, textBoxData.position)
                     print("Updated text box view \(textBoxData.id)") // Debug
                 }
                 
                 // Update border based on selection
                 existingView.layer.cornerRadius = 8.0 // Match SwiftUI
                 updateBorder(for: existingView, id: textBoxData.id, isSelected: selectedElementId == textBoxData.id)
                 
            } else {
                // Add new view
                let newTextView = UITextView()
                newTextView.text = textBoxData.text
                newTextView.font = UIFont.systemFont(ofSize: 17) // Match SwiftUI body font
                newTextView.backgroundColor = .clear
                newTextView.isScrollEnabled = false
                newTextView.isUserInteractionEnabled = true // Enable interaction
                
                // Calculate frame based on content
                let fixedWidth: CGFloat = 180 // Max width from SwiftUI
                let sizeThatFits = newTextView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
                newTextView.frame = CGRect(origin: textBoxData.position, size: CGSize(width: fixedWidth, height: sizeThatFits.height))
                
                // Add gesture recognizers
                let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                newTextView.addGestureRecognizer(panGesture)
                panGesture.delegate = self // Set delegate to handle simultaneous gestures
                
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                newTextView.addGestureRecognizer(tapGesture)
                
                // Store and add to view
                newTextView.tag = 1 // Tag to identify as text box
                newTextView.accessibilityIdentifier = textBoxData.id.uuidString // Store ID
                addSubview(newTextView)
                textBoxViews[textBoxData.id] = newTextView
                currentTextBoxData[textBoxData.id] = (textBoxData.text, textBoxData.position)
                
                // Add border if selected
                updateBorder(for: newTextView, id: textBoxData.id, isSelected: selectedElementId == textBoxData.id)
                
                print("Added text box view \(textBoxData.id)") // Debug
            }
        }
        
        // 3. Update or Add image views
        for imageData in images {
            if let existingView = imageViewViews[imageData.id] {
                 // Update existing view if data changed
                 if currentImageData[imageData.id]?.position != imageData.position {
                     currentImageData[imageData.id] = (imageData.image, imageData.position, imageData.imageUrl)
                     print("Updated image view \(imageData.id)") // Debug
                 }
                 
                 // Update border based on selection
                 existingView.layer.cornerRadius = 8.0 // Match SwiftUI
                 updateBorder(for: existingView, id: imageData.id, isSelected: selectedElementId == imageData.id)
                
            } else {
                // Add new view
                let newImageView = UIImageView(image: imageData.image)
                newImageView.frame = CGRect(origin: imageData.position, size: CGSize(width: 100, height: 100)) // Match SwiftUI size
                newImageView.contentMode = .scaleAspectFit // Match SwiftUI content mode
                newImageView.isUserInteractionEnabled = true // Enable interaction
                newImageView.clipsToBounds = true
                
                // Add gesture recognizers
                let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                newImageView.addGestureRecognizer(panGesture)
                panGesture.delegate = self // Set delegate
                
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                newImageView.addGestureRecognizer(tapGesture)
                
                // Store and add to view
                newImageView.tag = 2 // Tag to identify as image
                newImageView.accessibilityIdentifier = imageData.id.uuidString // Store ID
                addSubview(newImageView)
                imageViewViews[imageData.id] = newImageView
                currentImageData[imageData.id] = (imageData.image, imageData.position, imageData.imageUrl)
                
                // Add border if selected
                updateBorder(for: newImageView, id: imageData.id, isSelected: selectedElementId == imageData.id)
                
                print("Added image view \(imageData.id)") // Debug
            }
        }
        
        // 4. Update selection states - already handled in steps 2 and 3
        if currentSelectedElementId != selectedElementId {
             currentSelectedElementId = selectedElementId
             // Selection update is handled per view above.
        }
        
        // Ensure views are positioned correctly initially or after updates
         for (id, view) in textBoxViews {
             if let data = textBoxes.first(where: { $0.id == id }) {
                 view.frame.origin = data.position
             }
         }
         for (id, view) in imageViewViews {
             if let data = images.first(where: { $0.id == id }) {
                 view.frame.origin = data.position
             }
         }
    }
    
    // MARK: - Gesture Handling
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view, let idString = view.accessibilityIdentifier, let id = UUID(uuidString: idString) else { return }
        
        let translation = gesture.translation(in: self)
        
        if gesture.state == .began {
             // When dragging begins, select the element
             let elementType: CanvasElementType = (view.tag == 1) ? .textBox : .image
             delegate?.canvasElementDidSelect(textBoxId: (elementType == .textBox ? id : nil), imageId: (elementType == .image ? id : nil))
             // Store the initial center when the gesture begins
             // We will update the center directly in .changed
         }
        
        let newCenterX = view.center.x + translation.x
        let newCenterY = view.center.y + translation.y
        
        view.center = CGPoint(x: newCenterX, y: newCenterY)
        gesture.setTranslation(.zero, in: self) // Reset translation for the next change event
        
        if gesture.state == .ended {
            // When dragging ends, report the final position back to SwiftUI
            let elementType: CanvasElementType = (view.tag == 1) ? .textBox : .image
            delegate?.canvasElementDidMove(id: id, newPosition: view.frame.origin, elementType: elementType)
        }
        
        // Handle selection while dragging
        if gesture.state == .began || gesture.state == .changed {
            let elementType: CanvasElementType = (view.tag == 1) ? .textBox : .image
            delegate?.canvasElementDidSelect(textBoxId: (elementType == .textBox ? id : nil), imageId: (elementType == .image ? id : nil))
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
         guard let view = gesture.view, let idString = view.accessibilityIdentifier, let id = UUID(uuidString: idString) else { return }
         
         let elementType: CanvasElementType = (view.tag == 1) ? .textBox : .image
         delegate?.canvasElementDidSelect(textBoxId: (elementType == .textBox ? id : nil), imageId: (elementType == .image ? id : nil))
         
         // Bring the selected view to the front
         bringSubviewToFront(view)
         
         // Handle long press for deletion
         if gesture.state == .recognized && gesture.numberOfTapsRequired == 0 { // Check for long press state if needed later
              // This tap handler is not specifically for long press, but keeping this structure
              // for potential future expansion to long press for deletion.
              print("Tap recognized on element \(id)")
          }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    // Allow simultaneous pan gestures to enable dragging when one element is on top of another
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow a pan gesture to be recognized simultaneously with other pan gestures
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    // MARK: - Hit Testing for Deletion (Example - requires long press gesture)
    
    // This would typically be handled by a long press gesture and a confirmation alert.
    // Leaving this as a placeholder structure.
    func deleteElement(id: UUID, elementType: CanvasElementType) {
         // Find the view and remove it
         if elementType == .textBox, let view = textBoxViews[id] {
             view.removeFromSuperview()
             textBoxViews.removeValue(forKey: id)
             currentTextBoxData.removeValue(forKey: id)
             delegate?.canvasElementDidDelete(id: id, elementType: .textBox)
         } else if elementType == .image, let view = imageViewViews[id] {
              view.removeFromSuperview()
              imageViewViews.removeValue(forKey: id)
              currentImageData.removeValue(forKey: id)
              delegate?.canvasElementDidDelete(id: id, elementType: .image)
         }
    }
}
