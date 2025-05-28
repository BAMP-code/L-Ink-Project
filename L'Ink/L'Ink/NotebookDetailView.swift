import SwiftUI
import PencilKit

struct NotebookDetailView: View {
    @State var notebook: Notebook
    @StateObject private var viewModel: NotebookViewModel
    @State private var selectedPageIndex: Int
    @State private var showingNewPageSheet = false
    @State private var newPageType: PageType = .text
    @State private var rotation: Double = 0
    @State private var isFlipping = false
    @State private var isEditingPage = false
    @State private var myDrawing = PKDrawing()
    @State private var myIsDrawing = false
    @State private var myTextBoxes: [(id: UUID, text: String, position: CGPoint)] = []
    @State private var myImages: [(id: UUID, image: UIImage, position: CGPoint)] = []
    @State private var myShowImageInsert = false
    @State private var showSystemImagePicker = false
    @State private var imageToAdd: UIImage? = nil
    @State private var selectedTextBoxID: UUID? = nil
    @State private var selectedImageID: UUID? = nil
    @State private var drawingColors: [Color] = [.black, .red, .blue, .green, .orange]
    @State private var selectedDrawingColor: Color = .black
    @State private var editingTextBoxID: UUID? = nil
    
    init(notebook: Notebook) {
        var notebookCopy = notebook
        // Remove welcome text from first page if present
        if !notebookCopy.pages.isEmpty && notebookCopy.pages[0].content == "Welcome to your first page! You can write text here or create ink drawings." {
            notebookCopy.pages[0].content = ""
        }
        self.notebook = notebookCopy
        _viewModel = StateObject(wrappedValue: NotebookViewModel())
        _selectedPageIndex = State(initialValue: 0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 3D Notebook View or Canvas
            ZStack {
                if isEditingPage {
                    ZStack(alignment: .center) {
                        PageView(page: notebook.pages[selectedPageIndex], showWelcome: false, showCanvasElements: false)
                            .rotation3DEffect(
                                .degrees(0), // No rotation in edit mode
                                axis: (x: 0, y: 1, z: 0),
                                anchor: .leading,
                                perspective: 0.5
                            )
                            .opacity(1)
                            .zIndex(0)
                        MyDrawingCanvas(drawing: $myDrawing, isDrawingEnabled: myIsDrawing, drawingColor: selectedDrawingColor)
                            .background(Color.clear)
                            .zIndex(myIsDrawing ? 2 : 0)
                        if !myIsDrawing || (!myTextBoxes.isEmpty || !myImages.isEmpty) {
                            ForEach($myTextBoxes, id: \.id) { $box in
                                MyCanvasTextBox(
                                    text: $box.text,
                                    position: box.position,
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
                            ForEach(myImages, id: \.id) { img in
                                MyCanvasImage(
                                    image: img.image,
                                    position: img.position,
                                    selected: selectedImageID == img.id,
                                    onSelect: {
                                        selectedImageID = img.id
                                        selectedTextBoxID = nil
                                        editingTextBoxID = nil
                                    },
                                    onDelete: { myImages.removeAll { $0.id == img.id } }
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
                } else {
                    PageView(page: notebook.pages[selectedPageIndex], showWelcome: false, showCanvasElements: true)
                        .rotation3DEffect(
                            .degrees(rotation),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.5
                        )
                        .opacity(1)
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
                                saveLastViewedPage()
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
                                saveLastViewedPage()
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
            // Edit menu below the page in edit mode
            if isEditingPage {
                HStack(spacing: 32) {
                    Button(action: { myIsDrawing.toggle() }) {
                        Image(systemName: "pencil.tip")
                            .font(.title2)
                            .foregroundColor(myIsDrawing ? .blue : .primary)
                    }
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
                // Color picker menu for drawing
                if myIsDrawing {
                    HStack(spacing: 20) {
                        ForEach(drawingColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: selectedDrawingColor == color ? 3 : 1)
                                )
                                .onTapGesture {
                                    selectedDrawingColor = color
                                }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            Text("Page \(selectedPageIndex + 1) of \(notebook.pages.count)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            // Big Edit button
            Button(action: {
                if isEditingPage {
                    saveCanvasToPage()
                    // Clear all selection states when exiting edit mode
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
                    myImages.append((UUID(), image, CGPoint(x: 200, y: 200)))
                }
                showSystemImagePicker = false
            }
        }
        .onChange(of: selectedPageIndex) { _, _ in
            loadCanvasFromPage()
            saveLastViewedPage()
        }
    }
    
    private func saveLastViewedPage() {
        var updatedNotebook = notebook
        updatedNotebook.lastViewedPageIndex = selectedPageIndex
        viewModel.updateNotebook(updatedNotebook)
    }
    
    // New Drawing Canvas
    struct MyDrawingCanvas: UIViewRepresentable {
        @Binding var drawing: PKDrawing
        var isDrawingEnabled: Bool
        var drawingColor: Color
        func makeUIView(context: Context) -> PKCanvasView {
            let canvasView = PKCanvasView()
            canvasView.drawingPolicy = .anyInput
            canvasView.isUserInteractionEnabled = isDrawingEnabled
            canvasView.backgroundColor = .clear
            canvasView.tool = PKInkingTool(.pen, color: UIColor(drawingColor), width: 1)
            canvasView.drawing = drawing
            canvasView.delegate = context.coordinator
            return canvasView
        }
        func updateUIView(_ uiView: PKCanvasView, context: Context) {
            uiView.isUserInteractionEnabled = isDrawingEnabled
            // Only set the tool if it changed
            let currentTool = uiView.tool as? PKInkingTool
            let newTool = PKInkingTool(.pen, color: UIColor(drawingColor), width: 1)
            if currentTool?.color != newTool.color || currentTool?.inkType != newTool.inkType || currentTool?.width != newTool.width {
                uiView.tool = newTool
            }
            if uiView.drawing != drawing {
                uiView.drawing = drawing
            }
        }
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        class Coordinator: NSObject, PKCanvasViewDelegate {
            var parent: MyDrawingCanvas
            init(_ parent: MyDrawingCanvas) { self.parent = parent }
            func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
                parent.drawing = canvasView.drawing
            }
        }
    }

    // New Draggable Text Box
    struct MyCanvasTextBox: View {
        @Binding var text: String
        @State private var position: CGPoint
        var selected: Bool
        @Binding var isEditing: Bool
        var onSelect: () -> Void
        var onDelete: () -> Void
        @GestureState private var dragOffset: CGSize = .zero
        @State private var isMoving: Bool = false
        @State private var dragStart: CGPoint? = nil
        init(text: Binding<String>, position: CGPoint, selected: Bool, isEditing: Binding<Bool>, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
            self._text = text
            self._position = State(initialValue: position)
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
                                .onChanged { _ in onSelect() }
                                .onEnded { value in
                                    position.x += value.translation.width
                                    position.y += value.translation.height
                                }
                        )
                }
                if selected {
                    // Delete button (top right)
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .offset(x: 10, y: -10)
                    // Move button (bottom right)
                    Button(action: {}) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .foregroundColor(.blue)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 1)
                    }
                    .offset(x: 10, y: 32)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStart == nil { dragStart = position }
                                if let start = dragStart {
                                    isMoving = true
                                    position.x = start.x + value.translation.width
                                    position.y = start.y + value.translation.height
                                }
                            }
                            .onEnded { _ in
                                isMoving = false
                                dragStart = nil
                            }
                    )
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
        }
    }

    // New Draggable Image
    struct MyCanvasImage: View {
        let image: UIImage
        @State private var position: CGPoint
        var selected: Bool
        var onSelect: () -> Void
        var onDelete: () -> Void
        @GestureState private var dragOffset: CGSize = .zero
        @State private var isMoving: Bool = false
        @State private var dragStart: CGPoint? = nil
        init(image: UIImage, position: CGPoint, selected: Bool, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
            self.image = image
            self._position = State(initialValue: position)
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
                    // Delete button (top right)
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .offset(x: 10, y: -10)
                    // Move button (bottom right)
                    Button(action: {}) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .foregroundColor(.blue)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 1)
                    }
                    .offset(x: 10, y: 90)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStart == nil { dragStart = position }
                                if let start = dragStart {
                                    isMoving = true
                                    position.x = start.x + value.translation.width
                                    position.y = start.y + value.translation.height
                                }
                            }
                            .onEnded { _ in
                                isMoving = false
                                dragStart = nil
                            }
                    )
                }
            }
            .position(
                x: position.x.isFinite ? position.x : 100,
                y: position.y.isFinite ? position.y : 100
            )
            .onTapGesture { onSelect() }
        }
    }

    // New function to add a text box
    private func addMyTextBox() {
        myTextBoxes.append((UUID(), "New Text", CGPoint(x: 150, y: 150)))
    }

    // New function to add an image (use a real placeholder image)
    private func addMyImage() {
        if let placeholder = UIImage(systemName: "photo") {
            myImages.append((UUID(), placeholder, CGPoint(x: 200, y: 200)))
        }
    }

    // Save canvas state to page when toggling out of edit mode
    private func saveCanvasToPage() {
        let drawingData = myDrawing.dataRepresentation()
        let textBoxModels: [CanvasTextBoxModel] = myTextBoxes.map { box in
            CanvasTextBoxModel(
                id: box.id,
                text: box.text,
                position: CGPointCodable(box.position)
            )
        }
        let imageModels: [CanvasImageModel] = myImages.compactMap { img in
            if let imageData = img.image.pngData() {
                return CanvasImageModel(
                    id: img.id,
                    imageData: imageData,
                    position: CGPointCodable(img.position)
                )
            }
            return nil
        }
        
        // Create updated page
        var updatedPage = notebook.pages[selectedPageIndex]
        updatedPage.drawingData = drawingData
        updatedPage.textBoxes = textBoxModels
        updatedPage.images = imageModels
        updatedPage.updatedAt = Date()

        // Update the notebook's pages array
        var updatedNotebook = notebook
        updatedNotebook.pages[selectedPageIndex] = updatedPage
        updatedNotebook.updatedAt = Date()

        // Persist the change
        viewModel.updateNotebook(updatedNotebook)
        // Update local notebook so UI reflects changes
        notebook = updatedNotebook
    }

    // Load canvas state from page when entering edit mode or flipping pages
    private func loadCanvasFromPage() {
        let page = notebook.pages[selectedPageIndex]
        
        // Load drawing
        if let data = page.drawingData, let drawing = try? PKDrawing(data: data) {
            myDrawing = drawing
        } else {
            myDrawing = PKDrawing()
        }
        
        // Load text boxes with their positions
        myTextBoxes = page.textBoxes?.map { box in
            (box.id, box.text, box.position.cgPoint)
        } ?? []
        
        // Load images with their positions
        myImages = page.images?.compactMap { model in
            if let image = UIImage(data: model.imageData) {
                return (model.id, image, model.position.cgPoint)
            }
            return nil
        } ?? []
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
            parent.completion(image)
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
                            if let uiImage = UIImage(data: img.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                                    .position(
                                        x: img.position.x.isFinite ? img.position.x : 100,
                                        y: img.position.y.isFinite ? img.position.y : 100
                                    )
                            }
                        }
                    }
                    
                    // Display drawing if present
                    if let drawingData = page.drawingData,
                       let drawing = try? PKDrawing(data: drawingData) {
                        DrawingPreview(drawing: drawing)
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

struct DrawingPreview: UIViewRepresentable {
    let drawing: PKDrawing
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.isUserInteractionEnabled = false
        canvas.backgroundColor = .clear
        canvas.drawing = drawing
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
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
    @State private var canvasView = PKCanvasView()
    
    init(page: Page, onUpdate: @escaping (String) -> Void) {
        self.page = page
        self.onUpdate = onUpdate
        _textContent = State(initialValue: page.content)
    }
    
    var body: some View {
        Group {
            if page.type == .text {
                TextEditor(text: $textContent)
                    .onChange(of: textContent) { newValue in
                        onUpdate(newValue)
                    }
            } else {
                InkCanvasView(canvasView: $canvasView)
                    .onChange(of: canvasView.drawing) { _ in
                        // Convert drawing to data and update
                        if let data = try? canvasView.drawing.dataRepresentation() {
                            onUpdate(data.base64EncodedString())
                        }
                    }
            }
        }
        .padding()
    }
}

struct InkCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 1)
        canvasView.backgroundColor = .clear
        canvasView.drawingPolicy = .anyInput
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}




