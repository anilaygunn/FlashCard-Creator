import Foundation
import SwiftUI

// MARK: - Flashcard Model
struct Flashcard: Identifiable, Codable {
    let id = UUID()
    let imageName: String
    let answer: String
    var isCorrect: Bool = false
    var userScore: Int = 0 // -1 for wrong, +1 for right, 0 for not answered
}

// MARK: - Deck Model
struct Deck: Identifiable, Codable {
    let id = UUID()
    var name: String
    let folderPath: String
    var flashcards: [Flashcard]
    var totalScore: Int = 0
    var completedRounds: Int = 0
    var lastPlayedDate: Date?
    
    var averageScore: Double {
        guard completedRounds > 0 else { return 0 }
        return Double(totalScore) / Double(completedRounds)
    }
    
    var progressPercentage: Double {
        let answeredCards = flashcards.filter { $0.userScore != 0 }.count
        guard flashcards.count > 0 else { return 0 }
        return Double(answeredCards) / Double(flashcards.count) * 100
    }
}

// MARK: - Database Models
struct DatabaseCard: Codable {
    let id: String
    let front: String?
    let back: String?
    let frontImageFileName: String?
    let backImageFileName: String?
}

// MARK: - Game State
enum GameState {
    case showingQuestion
    case showingAnswer
    case gameComplete
}

// MARK: - App Storage Keys
struct StorageKeys {
    static let savedDecks = "savedDecks"
} 