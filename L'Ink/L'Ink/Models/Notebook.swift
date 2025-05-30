import Foundation
import FirebaseFirestore

enum PageType: String, Codable {
    case cover
    case text
    case ink
}

public struct Page: Identifiable, Codable {
    public var id: String
    var content: String
    var type: PageType
    var createdAt: Date
    var updatedAt: Date
    var order: Int
    // Persistent canvas state
    var drawingData: Data?
    var textBoxes: [CanvasTextBoxModel]?
    var images: [CanvasImageModel]? // Store URL, not Data in Firestore
}

public struct Notebook: Identifiable, Codable {
    public var id: String
    var title: String
    var description: String?
    var ownerId: String
    var isPublic: Bool
    var isPinned: Bool
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var pages: [Page]
    var lastViewedPageIndex: Int
    var coverImage: String
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String? = nil,
         ownerId: String,
         isPublic: Bool = false,
         isPinned: Bool = false,
         isFavorite: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         pages: [Page] = [],
         lastViewedPageIndex: Int = 0,
         coverImage: String = "Blue") {
        self.id = id
        self.title = title
        self.description = description
        self.ownerId = ownerId
        self.isPublic = isPublic
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pages = pages
        self.lastViewedPageIndex = lastViewedPageIndex
        self.coverImage = coverImage
    }
    
    // Firestore document conversion
    var dictionary: [String: Any] {
        return [
            "id": id,
            "title": title,
            "description": description as Any,
            "ownerId": ownerId,
            "isPublic": isPublic,
            "isPinned": isPinned,
            "isFavorite": isFavorite,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "lastViewedPageIndex": lastViewedPageIndex,
            "coverImage": coverImage,
            "pages": pages.map { page in
                var pageDict: [String: Any] = [
                    "id": page.id,
                    "content": page.content,
                    "type": page.type.rawValue,
                    "createdAt": Timestamp(date: page.createdAt),
                    "updatedAt": Timestamp(date: page.updatedAt),
                    "order": page.order
                ]
                
                if let drawingData = page.drawingData {
                    pageDict["drawingData"] = drawingData
                }
                
                if let textBoxes = page.textBoxes {
                    pageDict["textBoxes"] = textBoxes.map { box in
                        var boxDict: [String: Any] = [
                            "id": box.id.uuidString,
                            "text": box.text,
                            "position": ["x": box.position.x, "y": box.position.y]
                        ]
                        
                        if let size = box.size {
                            boxDict["size"] = ["width": size.width, "height": size.height]
                        }
                        
                        return boxDict
                    }
                }
                
                if let images = page.images {
                    pageDict["images"] = images.compactMap { img in
                        if let imageUrl = img.imageUrl {
                            var imgDict: [String: Any] = [
                                "id": img.id.uuidString,
                                "imageUrl": imageUrl,
                                "position": ["x": img.position.x, "y": img.position.y]
                            ]
                            
                            if let size = img.size {
                                imgDict["size"] = ["width": size.width, "height": size.height]
                            }
                            
                            return imgDict
                        }
                        return nil
                    }
                }
                
                return pageDict
            }
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> Notebook? {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let ownerId = dict["ownerId"] as? String,
              let isPublic = dict["isPublic"] as? Bool,
              let isPinned = dict["isPinned"] as? Bool,
              let isFavorite = dict["isFavorite"] as? Bool,
              let createdAt = (dict["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (dict["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let description = dict["description"] as? String
        let lastViewedPageIndex = dict["lastViewedPageIndex"] as? Int ?? 0
        let coverImage = dict["coverImage"] as? String ?? "Blue"
        let pages = (dict["pages"] as? [[String: Any]])?.compactMap { pageDict -> Page? in
            guard let pageId = pageDict["id"] as? String,
                  let content = pageDict["content"] as? String,
                  let typeString = pageDict["type"] as? String,
                  let type = PageType(rawValue: typeString),
                  let pageCreatedAt = (pageDict["createdAt"] as? Timestamp)?.dateValue(),
                  let pageUpdatedAt = (pageDict["updatedAt"] as? Timestamp)?.dateValue(),
                  let order = pageDict["order"] as? Int else {
                return nil
            }
            
            return Page(
                id: pageId,
                content: content,
                type: type,
                createdAt: pageCreatedAt,
                updatedAt: pageUpdatedAt,
                order: order,
                drawingData: pageDict["drawingData"] as? Data,
                textBoxes: (pageDict["textBoxes"] as? [[String: Any]])?.compactMap { boxDict -> CanvasTextBoxModel? in
                    guard let idString = boxDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let text = boxDict["text"] as? String,
                          let positionDict = boxDict["position"] as? [String: CGFloat],
                          let x = positionDict["x"],
                          let y = positionDict["y"] else {
                        return nil
                    }
                    var size: CGSizeCodable?
                    if let sizeDict = boxDict["size"] as? [String: CGFloat],
                       let width = sizeDict["width"],
                       let height = sizeDict["height"] {
                        size = CGSizeCodable(CGSize(width: width, height: height))
                    }
                    return CanvasTextBoxModel(
                        id: id,
                        text: text,
                        position: CGPointCodable(CGPoint(x: x, y: y)),
                        size: size
                    )
                },
                images: (pageDict["images"] as? [[String: Any]])?.compactMap { imgDict -> CanvasImageModel? in
                    guard let idString = imgDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let imageUrl = imgDict["imageUrl"] as? String,
                          let positionDict = imgDict["position"] as? [String: CGFloat],
                          let x = positionDict["x"],
                          let y = positionDict["y"] else {
                        return nil
                    }
                    
                    var size: CGSizeCodable? = nil
                    if let sizeDict = imgDict["size"] as? [String: CGFloat],
                       let width = sizeDict["width"],
                       let height = sizeDict["height"] {
                        size = CGSizeCodable(CGSize(width: width, height: height))
                    }
                    
                    return CanvasImageModel(
                        id: id,
                        imageData: nil,
                        imageUrl: imageUrl,
                        position: CGPointCodable(CGPoint(x: x, y: y)),
                        size: size
                    )
                }
            )
        } ?? []
        
        return Notebook(
            id: id,
            title: title,
            description: description,
            ownerId: ownerId,
            isPublic: isPublic,
            isPinned: isPinned,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            pages: pages,
            lastViewedPageIndex: lastViewedPageIndex,
            coverImage: coverImage
        )
    }
}

// Add Codable models for text boxes and images if not already present
public struct CanvasTextBoxModel: Codable, Identifiable {
    public var id: UUID
    var text: String
    var position: CGPointCodable
    var size: CGSizeCodable?
}

public struct CanvasImageModel: Codable, Identifiable {
    public var id: UUID
    var imageData: Data? // Temporarily hold data before upload
    var imageUrl: String? // Store URL in Firestore
    var position: CGPointCodable
    var size: CGSizeCodable?
}

public struct CGPointCodable: Codable {
    var x: CGFloat
    var y: CGFloat
    init(_ point: CGPoint) { x = point.x; y = point.y }
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

public struct CGSizeCodable: Codable {
    var width: CGFloat
    var height: CGFloat
    init(_ size: CGSize) { width = size.width; height = size.height }
    var cgSize: CGSize { CGSize(width: width, height: height) }
} 
