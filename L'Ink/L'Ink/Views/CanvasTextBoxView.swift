import SwiftUI

struct EditableTextBoxView: View {
    let box: (id: UUID, text: String, position: CGPoint)
    let isEditing: Bool
    let isSelected: Bool
    let size: CGSize
    let onTextChange: (String) -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    let onDrag: (CGPoint) -> Void
    let onResize: (CGSize) -> Void
    
    @State private var isResizing = false
    @State private var resizeStartSize: CGSize = .zero
    @State private var resizeStartPoint: CGPoint = .zero
    
    var body: some View {
        Group {
            if isEditing {
                createEditingView()
            } else {
                createDisplayView()
            }
        }
        .position(box.position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isResizing {
                        onDrag(value.location)
                    }
                }
        )
        .onTapGesture {
            onTap()
        }
        .overlay(
            Group {
                if isSelected {
                    createResizeHandles()
                }
            }
        )
    }
    
    private func createEditingView() -> some View {
        TextField("Enter text", text: Binding(
            get: { box.text },
            set: { onTextChange($0) }
        ))
        .font(.body)
        .frame(width: size.width, height: size.height)
        .fixedSize(horizontal: false, vertical: true)
        .padding(8)
        .background(Color.white.opacity(0.9))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 1)
        )
        .overlay(
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .padding(4),
            alignment: .topTrailing
        )
    }
    
    private func createDisplayView() -> some View {
        Text(box.text)
            .font(.body)
            .frame(width: size.width, height: size.height)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .background(Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
            .overlay(
                Group {
                    if isSelected {
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .padding(4)
                    }
                },
                alignment: .topTrailing
            )
    }
    
    private func createResizeHandles() -> some View {
        ZStack {
            createResizeHandle(corner: .topLeft)
            createResizeHandle(corner: .topRight)
            createResizeHandle(corner: .bottomLeft)
            createResizeHandle(corner: .bottomRight)
        }
    }
    
    private func createResizeHandle(corner: UIRectCorner) -> some View {
        let handleSize: CGFloat = 20 // Increased handle size
        let touchSize: CGFloat = 44 // Larger touch target
        let x: CGFloat
        let y: CGFloat
        
        switch corner {
        case .topLeft:
            x = box.position.x - size.width/2
            y = box.position.y - size.height/2
        case .topRight:
            x = box.position.x + size.width/2
            y = box.position.y - size.height/2
        case .bottomLeft:
            x = box.position.x - size.width/2
            y = box.position.y + size.height/2
        case .bottomRight:
            x = box.position.x + size.width/2
            y = box.position.y + size.height/2
        default:
            x = box.position.x
            y = box.position.y
        }
        
        return Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .frame(width: touchSize, height: touchSize) // Larger touch target
            .contentShape(Rectangle()) // Make the entire touch area interactive
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isResizing {
                            isResizing = true
                            resizeStartSize = size
                            resizeStartPoint = value.location
                        }
                        
                        let deltaX = value.location.x - resizeStartPoint.x
                        let deltaY = value.location.y - resizeStartPoint.y
                        var newSize = resizeStartSize
                        
                        switch corner {
                        case .topLeft:
                            newSize.width = max(60, resizeStartSize.width - deltaX * 2)
                            newSize.height = max(32, resizeStartSize.height - deltaY * 2)
                        case .topRight:
                            newSize.width = max(60, resizeStartSize.width + deltaX * 2)
                            newSize.height = max(32, resizeStartSize.height - deltaY * 2)
                        case .bottomLeft:
                            newSize.width = max(60, resizeStartSize.width - deltaX * 2)
                            newSize.height = max(32, resizeStartSize.height + deltaY * 2)
                        case .bottomRight:
                            newSize.width = max(60, resizeStartSize.width + deltaX * 2)
                            newSize.height = max(32, resizeStartSize.height + deltaY * 2)
                        default:
                            break
                        }
                        
                        onResize(newSize)
                    }
                    .onEnded { _ in
                        isResizing = false
                    }
            )
    }
} 