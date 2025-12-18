import SwiftUI
import SwiftUICore

struct GameView: View {
    let deck: Deck
    let databaseManager: DatabaseManager
    
    @State private var currentCardIndex = 0
    @State private var gameState: GameState = .showingQuestion
    @State private var currentDeck: Deck
    @State private var sessionScore = 0
    @State private var showingGameComplete = false
    @Environment(\.dismiss) private var dismiss
    
    init(deck: Deck, databaseManager: DatabaseManager) {
        self.deck = deck
        self.databaseManager = databaseManager
        // Create a copy of the deck and shuffle its flashcards
        var shuffledDeck = deck
        shuffledDeck.flashcards.shuffle()
        self._currentDeck = State(initialValue: shuffledDeck)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Progress and Score Header
                headerView
                
                // Main Card Area
                if currentCardIndex < currentDeck.flashcards.count {
                    flashcardView
                }
                
                Spacer()
                
                // Control Buttons
                if gameState == .showingAnswer {
                    scoringButtons
                } else if gameState == .showingQuestion {
                    showAnswerButton
                }
            }
            .padding()
        }
        .navigationTitle(currentDeck.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Exit") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(sessionScore)")
                        .fontWeight(.bold)
                }
            }
        }
        .sheet(isPresented: $showingGameComplete) {
            NavigationStack {
                GameCompleteView(
                    deck: currentDeck,
                    sessionScore: sessionScore,
                    onRestart: restartGame,
                    onExit: { dismiss() }
                )
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Progress bar
            HStack {
                Text("Card \(currentCardIndex + 1) of \(currentDeck.flashcards.count)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Session: \(sessionScore)")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(sessionScore >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .cornerRadius(20)
            }
            
            ProgressView(value: Double(currentCardIndex), total: Double(currentDeck.flashcards.count))
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 3)
        }
    }
    
    private var flashcardView: some View {
        let currentCard = currentDeck.flashcards[currentCardIndex]
        
        print("\nLoading flashcard:")
        print("Image name: \(currentCard.imageName)")
        print("Answer: \(currentCard.answer)")
        
        return VStack(spacing: 20) {
            // Image Section
            if let imageURL = getImageURL(for: currentCard.imageName) {
                
               
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                                                RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Loading...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                    case .success(let image):
                        
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    case .failure(let error):
                       
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.red)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: 400)
            } else {
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Image not found")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxHeight: 400)
            }
            
            // Answer Section (only visible when showing answer)
            if gameState == .showingAnswer {
                VStack(spacing: 12) {
                    Text("Answer:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(currentCard.answer)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameState)
    }
    
    private var showAnswerButton: some View {
        Button {
            withAnimation {
                gameState = .showingAnswer
            }
        } label: {
            Text("Show Answer")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.gradient)
                .cornerRadius(12)
        }
    }
    
    private var scoringButtons: some View {
        VStack(spacing: 16) {
            Text("How did you do?")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                // Wrong Answer Button
                Button {
                    answerCard(correct: false)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 40))
                        Text("Wrong")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.red.gradient)
                    .cornerRadius(16)
                }
                
                // Correct Answer Button
                Button {
                    answerCard(correct: true)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                        Text("Correct")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.green.gradient)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    private func getImageURL(for imageName: String) -> URL? {
        return databaseManager.getImageURL(for: imageName)
    }
    
    private func answerCard(correct: Bool) {
        let score = correct ? 1 : +0 
        sessionScore += score
        
        // Update the flashcard
        currentDeck.flashcards[currentCardIndex].userScore = score
        currentDeck.flashcards[currentCardIndex].isCorrect = correct
        
        // Move to next card or finish game
        withAnimation {
            if currentCardIndex < currentDeck.flashcards.count - 1 {
                currentCardIndex += 1
                gameState = .showingQuestion
            } else {
                finishGame()
            }
        }
    }
    
    private func finishGame() {
        // Update deck statistics
        currentDeck.totalScore += sessionScore
        currentDeck.completedRounds += 1
        currentDeck.lastPlayedDate = Date()
        
        // Save the updated deck
        databaseManager.updateDeck(currentDeck)
        
        // Show completion screen
        showingGameComplete = true
    }
    
    private func restartGame() {
        currentCardIndex = 0
        sessionScore = 0
        gameState = .showingQuestion
        
        // Reset flashcard scores for new session
        for i in 0..<currentDeck.flashcards.count {
            currentDeck.flashcards[i].userScore = 0
            currentDeck.flashcards[i].isCorrect = false
        }
        
        // Shuffle cards for variety
        currentDeck.flashcards.shuffle()
        
        showingGameComplete = false
    }
}

struct GameCompleteView: View {
    let deck: Deck
    let sessionScore: Int
    let onRestart: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Trophy or celebration icon
            Image(systemName: sessionScore >= 0 ? "trophy.fill" : "hand.thumbsup.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)
            
            VStack(spacing: 16) {
                Text("YASSSSASIIINN IDILIMMM")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("SUPERSIN SEVGILIIIMMMM <3!")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text("Session Score: \(sessionScore)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(sessionScore >= 0 ? .green : .red)
                
                VStack(spacing: 8) {
                    Text("Deck Statistics")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack {
                            Text("\(deck.completedRounds)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Rounds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text(String(format: "%.1f", deck.averageScore))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Avg Score")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("\(deck.totalScore)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
            
            VStack(spacing: 16) {
                Button {
                    onRestart()
                } label: {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .cornerRadius(12)
                }
                
                Button {
                    onExit()
                } label: {
                    Text("Back to Decks")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let sampleDeck = Deck(
        name: "Sample Deck",
        folderPath: "/sample/path",
        flashcards: [
            Flashcard(imageName: "sample.jpg", answer: "Sample Answer")
        ]
    )
    
    GameView(deck: sampleDeck, databaseManager: DatabaseManager())
} 
