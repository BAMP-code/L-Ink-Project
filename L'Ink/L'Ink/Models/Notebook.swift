import Foundation
import FirebaseFirestore

enum PageType: String, Codable {
    case cover
    case text
    case ink
}

struct Page: Identifiable, Codable {
    var id: String
    var content: String
    var type: PageType
    var createdAt: Date
    var updatedAt: Date
    var order: Int
    // Persistent canvas state
    var drawingData: Data?
    var textBoxes: [CanvasTextBoxModel]?
    var images: [CanvasImageModel]?
}

struct Notebook: Identifiable, Codable {
    var id: String
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
                [
                    "id": page.id,
                    "content": page.content,
                    "type": page.type.rawValue,
                    "createdAt": Timestamp(date: page.createdAt),
                    "updatedAt": Timestamp(date: page.updatedAt),
                    "order": page.order
                ]
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
                order: order
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
struct CanvasTextBoxModel: Codable, Identifiable {
    var id: UUID
    var text: String
    var position: CGPointCodable
}

struct CanvasImageModel: Codable, Identifiable {
    var id: UUID
    var imageData: Data
    var position: CGPointCodable
}

struct CGPointCodable: Codable {
    var x: CGFloat
    var y: CGFloat
    init(_ point: CGPoint) { x = point.x; y = point.y }
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
} 
