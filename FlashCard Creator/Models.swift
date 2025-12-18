import Foundation
import SwiftUI

// MARK: - Flashcard Model
struct Flashcard: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let imageName: String
    let answer: String
    var isCorrect: Bool = false
    var userScore: Int = 0 // -1 for wrong, +1 for right, 0 for not answered
    
    static func == (lhs: Flashcard, rhs: Flashcard) -> Bool {
        return lhs.id == rhs.id &&
               lhs.imageName == rhs.imageName &&
               lhs.answer == rhs.answer &&
               lhs.isCorrect == rhs.isCorrect &&
               lhs.userScore == rhs.userScore
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Deck Model
struct Deck: Identifiable, Codable, Hashable {
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
    
    static func == (lhs: Deck, rhs: Deck) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.folderPath == rhs.folderPath &&
               lhs.flashcards == rhs.flashcards &&
               lhs.totalScore == rhs.totalScore &&
               lhs.completedRounds == rhs.completedRounds &&
               lhs.lastPlayedDate == rhs.lastPlayedDate
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
