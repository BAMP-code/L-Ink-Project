import Foundation

// User interaction data structure
struct UserInteraction {
    let userId: String
    let notebookId: String
    let interactionType: InteractionType
    let timestamp: Date
    let value: Double // normalized value of the interaction (e.g., time spent, rating)
}

enum InteractionType: String {
    case view
    case like
    case comment
    case save
    case share
    case timeSpent
}

class RecommendationEngine {
    private var userInteractions: [UserInteraction] = []
    private var userSimilarityMatrix: [String: [String: Double]] = [:] // userId: [otherUserId: similarity]
    private var notebookSimilarityMatrix: [String: [String: Double]] = [:] // notebookId: [otherNotebookId: similarity]
    
    // Hyperparameters
    private let similarityThreshold = 0.3
    private let recentInteractionWeight = 0.7
    private let maxInteractionAge = 30.0 // days
    
    // Add a new interaction and update matrices
    func addInteraction(_ interaction: UserInteraction) {
        userInteractions.append(interaction)
        updateSimilarityMatrices(for: interaction)
    }
    
    // Update similarity matrices when new interaction is added
    private func updateSimilarityMatrices(for newInteraction: UserInteraction) {
        // Update user similarity matrix
        let userInteractions = getUserInteractions(for: newInteraction.userId)
        for otherUserId in getAllUsers() where otherUserId != newInteraction.userId {
            let otherUserInteractions = getUserInteractions(for: otherUserId)
            let similarity = calculateUserSimilarity(userInteractions, otherUserInteractions)
            userSimilarityMatrix[newInteraction.userId, default: [:]][otherUserId] = similarity
            userSimilarityMatrix[otherUserId, default: [:]][newInteraction.userId] = similarity
        }
        
        // Update notebook similarity matrix
        let notebookInteractions = getNotebookInteractions(for: newInteraction.notebookId)
        for otherNotebookId in getAllNotebooks() where otherNotebookId != newInteraction.notebookId {
            let otherNotebookInteractions = getNotebookInteractions(for: otherNotebookId)
            let similarity = calculateNotebookSimilarity(notebookInteractions, otherNotebookInteractions)
            notebookSimilarityMatrix[newInteraction.notebookId, default: [:]][otherNotebookId] = similarity
            notebookSimilarityMatrix[otherNotebookId, default: [:]][newInteraction.notebookId] = similarity
        }
    }
    
    // Get predicted score for a user-notebook pair
    func getPredictedScore(userId: String, notebookId: String) -> Double {
        let userBasedScore = calculateUserBasedScore(userId: userId, notebookId: notebookId)
        let itemBasedScore = calculateItemBasedScore(userId: userId, notebookId: notebookId)
        
        // Combine both scores with weights
        return 0.6 * userBasedScore + 0.4 * itemBasedScore
    }
    
    // Calculate score based on similar users' interactions
    private func calculateUserBasedScore(userId: String, notebookId: String) -> Double {
        guard let similarUsers = userSimilarityMatrix[userId] else { return 0.0 }
        
        var weightedSum = 0.0
        var similaritySum = 0.0
        
        for (otherUserId, similarity) in similarUsers where similarity > similarityThreshold {
            if let interactionValue = getInteractionValue(userId: otherUserId, notebookId: notebookId) {
                weightedSum += similarity * interactionValue
                similaritySum += similarity
            }
        }
        
        return similaritySum > 0 ? weightedSum / similaritySum : 0.0
    }
    
    // Calculate score based on similar items' interactions
    private func calculateItemBasedScore(userId: String, notebookId: String) -> Double {
        guard let similarNotebooks = notebookSimilarityMatrix[notebookId] else { return 0.0 }
        
        var weightedSum = 0.0
        var similaritySum = 0.0
        
        for (otherNotebookId, similarity) in similarNotebooks where similarity > similarityThreshold {
            if let interactionValue = getInteractionValue(userId: userId, notebookId: otherNotebookId) {
                weightedSum += similarity * interactionValue
                similaritySum += similarity
            }
        }
        
        return similaritySum > 0 ? weightedSum / similaritySum : 0.0
    }
    
    // Calculate similarity between two users based on their interactions
    private func calculateUserSimilarity(_ user1Interactions: [UserInteraction], _ user2Interactions: [UserInteraction]) -> Double {
        let user1NotebookIds = Set(user1Interactions.map { $0.notebookId })
        let user2NotebookIds = Set(user2Interactions.map { $0.notebookId })
        let commonNotebooks = user1NotebookIds.intersection(user2NotebookIds)
        
        if commonNotebooks.isEmpty { return 0.0 }
        
        var similarity = 0.0
        for notebookId in commonNotebooks {
            let user1Value = normalizedInteractionValue(for: user1Interactions, notebookId: notebookId)
            let user2Value = normalizedInteractionValue(for: user2Interactions, notebookId: notebookId)
            similarity += 1.0 - abs(user1Value - user2Value)
        }
        
        return similarity / Double(commonNotebooks.count)
    }
    
    // Calculate similarity between two notebooks based on user interactions
    private func calculateNotebookSimilarity(_ notebook1Interactions: [UserInteraction], _ notebook2Interactions: [UserInteraction]) -> Double {
        let notebook1UserIds = Set(notebook1Interactions.map { $0.userId })
        let notebook2UserIds = Set(notebook2Interactions.map { $0.userId })
        let commonUsers = notebook1UserIds.intersection(notebook2UserIds)
        
        if commonUsers.isEmpty { return 0.0 }
        
        var similarity = 0.0
        for userId in commonUsers {
            let value1 = normalizedInteractionValue(for: notebook1Interactions, userId: userId)
            let value2 = normalizedInteractionValue(for: notebook2Interactions, userId: userId)
            similarity += 1.0 - abs(value1 - value2)
        }
        
        return similarity / Double(commonUsers.count)
    }
    
    // Helper functions
    private func getUserInteractions(for userId: String) -> [UserInteraction] {
        return userInteractions.filter { $0.userId == userId }
    }
    
    private func getNotebookInteractions(for notebookId: String) -> [UserInteraction] {
        return userInteractions.filter { $0.notebookId == notebookId }
    }
    
    private func getAllUsers() -> Set<String> {
        return Set(userInteractions.map { $0.userId })
    }
    
    private func getAllNotebooks() -> Set<String> {
        return Set(userInteractions.map { $0.notebookId })
    }
    
    private func getInteractionValue(userId: String, notebookId: String) -> Double? {
        let interactions = userInteractions.filter { $0.userId == userId && $0.notebookId == notebookId }
        return interactions.isEmpty ? nil : normalizedInteractionValue(for: interactions)
    }
    
    private func normalizedInteractionValue(for interactions: [UserInteraction], notebookId: String? = nil, userId: String? = nil) -> Double {
        let relevantInteractions = interactions.filter { interaction in
            if let notebookId = notebookId {
                return interaction.notebookId == notebookId
            } else if let userId = userId {
                return interaction.userId == userId
            }
            return true
        }
        
        var totalValue = 0.0
        for interaction in relevantInteractions {
            let ageInDays = Date().timeIntervalSince(interaction.timestamp) / (24 * 3600)
            let timeDecay = max(0, 1.0 - (ageInDays / maxInteractionAge))
            totalValue += interaction.value * timeDecay
        }
        
        return min(1.0, totalValue / Double(relevantInteractions.count))
    }
} 