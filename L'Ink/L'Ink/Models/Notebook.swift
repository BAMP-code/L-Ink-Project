import Foundation
import FirebaseFirestore

enum PageType: String, Codable {
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
}

struct Notebook: Identifiable, Codable {
    var id: String
    var title: String
    var description: String?
    var ownerId: String
    var isPublic: Bool
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date
    var pages: [Page]
    var lastViewedPageIndex: Int
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String? = nil,
         ownerId: String,
         isPublic: Bool = false,
         isPinned: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         pages: [Page] = [],
         lastViewedPageIndex: Int = 0) {
        self.id = id
        self.title = title
        self.description = description
        self.ownerId = ownerId
        self.isPublic = isPublic
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pages = pages
        self.lastViewedPageIndex = lastViewedPageIndex
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
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "lastViewedPageIndex": lastViewedPageIndex,
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
              let createdAt = (dict["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (dict["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let description = dict["description"] as? String
        let lastViewedPageIndex = dict["lastViewedPageIndex"] as? Int ?? 0
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
            createdAt: createdAt,
            updatedAt: updatedAt,
            pages: pages,
            lastViewedPageIndex: lastViewedPageIndex
        )
    }
} 
