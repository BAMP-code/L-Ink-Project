import SwiftUI

struct EditableImageView: View {
    let img: (id: UUID, image: UIImage, position: CGPoint, imageURL: URL?)
    let isSelected: Bool
    let size: CGSize
    let onDelete: () -> Void
    let onTap: () -> Void
    let onDrag: (CGPoint) -> Void
    let onResize: (CGSize) -> Void
    
    @State private var isResizing = false
    @State private var resizeStartSize: CGSize = .zero
    @State private var resizeStartPoint: CGPoint = .zero
    
    // Calculate the aspect ratio of the image
    private var aspectRatio: CGFloat {
        let imageSize = img.image.size
        return imageSize.width / imageSize.height
    }
    
    var body: some View {
        ZStack {
            // Image with its border
            Image(uiImage: img.image)
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
            
            // Delete button overlay
            if isSelected {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .padding(4)
                .offset(x: size.width/2 - 20, y: -size.height/2 + 20)
            }
        }
        .position(img.position)
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
            x = img.position.x - size.width/2
            y = img.position.y - size.height/2
        case .topRight:
            x = img.position.x + size.width/2
            y = img.position.y - size.height/2
        case .bottomLeft:
            x = img.position.x - size.width/2
            y = img.position.y + size.height/2
        case .bottomRight:
            x = img.position.x + size.width/2
            y = img.position.y + size.height/2
        default:
            x = img.position.x
            y = img.position.y
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
                        
                        // Calculate new size based on the corner being dragged
                        switch corner {
                        case .topLeft:
                            newSize.width = max(100, resizeStartSize.width - deltaX * 2)
                            newSize.height = newSize.width / aspectRatio
                        case .topRight:
                            newSize.width = max(100, resizeStartSize.width + deltaX * 2)
                            newSize.height = newSize.width / aspectRatio
                        case .bottomLeft:
                            newSize.width = max(100, resizeStartSize.width - deltaX * 2)
                            newSize.height = newSize.width / aspectRatio
                        case .bottomRight:
                            newSize.width = max(100, resizeStartSize.width + deltaX * 2)
                            newSize.height = newSize.width / aspectRatio
                        default:
                            break
                        }
                        
                        // Ensure minimum height
                        if newSize.height < 100 {
                            newSize.height = 100
                            newSize.width = newSize.height * aspectRatio
                        }
                        
                        onResize(newSize)
                    }
                    .onEnded { _ in
                        isResizing = false
                    }
            )
    }
} 