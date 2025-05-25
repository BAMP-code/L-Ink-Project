import SwiftUI
import PencilKit

struct NotebookDetailView: View {
    let notebook: Notebook
    @StateObject private var viewModel: NotebookViewModel
    @State private var selectedPageIndex = 0
    @State private var showingNewPageSheet = false
    @State private var newPageType: PageType = .text
    @State private var rotation: Double = 0
    @State private var isFlipping = false
    @State private var isPageSelectorExpanded = false
    
    init(notebook: Notebook) {
        self.notebook = notebook
        _viewModel = StateObject(wrappedValue: NotebookViewModel())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Page selector header
            VStack(spacing: 0) {
                // Dropdown button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPageSelectorExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .rotationEffect(.degrees(isPageSelectorExpanded ? 180 : 0))
                        Text("Pages")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Page selector
                if isPageSelectorExpanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(notebook.pages.enumerated()), id: \.element.id) { index, page in
                                PageThumbnail(
                                    page: page,
                                    isSelected: index == selectedPageIndex
                                )
                                .onTapGesture {
                                    withAnimation {
                                        selectedPageIndex = index
                                    }
                                }
                            }
                            
                            // Add new page button
                            Button(action: { showingNewPageSheet = true }) {
                                VStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                    Text("New Page")
                                        .font(.caption)
                                }
                                .frame(width: 60, height: 80)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color(.systemBackground))
            
            // 3D Notebook View
            ZStack {
                // Notebook Cover
                NotebookCover(notebook: notebook)
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .trailing,
                        perspective: 0.5
                    )
                    .opacity(selectedPageIndex == 0 ? 1 : 0)
                
                // Pages
                ForEach(Array(notebook.pages.enumerated()), id: \.element.id) { index, page in
                    PageView(page: page)
                        .rotation3DEffect(
                            .degrees(rotation),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .trailing,
                            perspective: 0.5
                        )
                        .opacity(selectedPageIndex == index ? 1 : 0)
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
                        if value.translation.width < -100 && selectedPageIndex < notebook.pages.count - 1 {
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
                Button(action: previousPage) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundColor(selectedPageIndex > 0 ? .blue : .gray)
                }
                .disabled(selectedPageIndex == 0)
                
                Spacer()
                
                Text("Page \(selectedPageIndex + 1) of \(notebook.pages.count + 1)")
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextPage) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                        .foregroundColor(selectedPageIndex < notebook.pages.count ? .blue : .gray)
                }
                .disabled(selectedPageIndex == notebook.pages.count)
            }
            .padding()
        }
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewPageSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Page Type")) {
                        Picker("Type", selection: $newPageType) {
                            Text("Text").tag(PageType.text)
                            Text("Ink").tag(PageType.ink)
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
                        showingNewPageSheet = false
                    }
                )
            }
        }
    }
    
    private func nextPage() {
        if selectedPageIndex < notebook.pages.count {
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
    }
    
    private func previousPage() {
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
    }
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
                    } else {
                        // For ink pages, we'll show a preview of the drawing
                        if let data = Data(base64Encoded: page.content),
                           let drawing = try? PKDrawing(data: data) {
                            DrawingPreview(drawing: drawing)
                        } else {
                            Text("No drawing")
                                .foregroundColor(.gray)
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
