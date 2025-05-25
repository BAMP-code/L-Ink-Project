import Foundation
import FirebaseFirestore

struct AppUser: Identifiable, Codable {
    var id: String
    var username: String
    var email: String
    var profileImageURL: String?
    var headerImageURL: String?
    var bio: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String = UUID().uuidString,
         username: String,
         email: String,
         profileImageURL: String? = nil,
         headerImageURL: String? = nil,
         bio: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.profileImageURL = profileImageURL
        self.headerImageURL = headerImageURL
        self.bio = bio
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Firestore document conversion
    var dictionary: [String: Any] {
        return [
            "id": id,
            "username": username,
            "email": email,
            "profileImageURL": profileImageURL as Any,
            "headerImageURL": headerImageURL as Any,
            "bio": bio as Any,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> AppUser? {
        guard let id = dict["id"] as? String,
              let username = dict["username"] as? String,
              let email = dict["email"] as? String,
              let createdAt = (dict["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (dict["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let profileImageURL = dict["profileImageURL"] as? String
        let headerImageURL = dict["headerImageURL"] as? String
        let bio = dict["bio"] as? String
        
        return AppUser(
            id: id,
            username: username,
            email: email,
            profileImageURL: profileImageURL,
            headerImageURL: headerImageURL,
            bio: bio,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
} 