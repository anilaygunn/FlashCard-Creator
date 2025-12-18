import SwiftUI

struct DeckListView: View {
    @StateObject private var databaseManager = DatabaseManager()
    @State private var showingDocumentPicker = false
    @State private var showingDeckNameInput = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedFolderURL: URL?
    @State private var deckName = ""
    @State private var showingMergeSheet = false
    @State private var selectedDecks: Set<Deck> = []
    @State private var mergedDeckName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if databaseManager.availableDecks.isEmpty {
                        emptyStateView
                    } else {
                        deckListView
                    }
                }
                .padding()
            }
            .navigationTitle("Flashcard Decks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if databaseManager.availableDecks.count >= 2 {
                            Button {
                                showingMergeSheet = true
                            } label: {
                                Image(systemName: "rectangle.stack.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    selectedFolderURL = url
                    deckName = url.lastPathComponent // Default deck name
                    showingDeckNameInput = true
                }
            }
            .sheet(isPresented: $showingMergeSheet) {
                NavigationStack {
                    VStack(spacing: 20) {
                        Text("Select Decks to Merge")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        List(databaseManager.availableDecks, id: \.id) { deck in
                            HStack {
                                Text(deck.name)
                                Spacer()
                                if selectedDecks.contains(deck) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedDecks.contains(deck) {
                                    selectedDecks.remove(deck)
                                } else if selectedDecks.count < 2 {
                                    selectedDecks.insert(deck)
                                }
                            }
                        }
                        
                        if selectedDecks.count == 2 {
                            VStack(spacing: 12) {
                                Text("New Deck Name")
                                    .font(.headline)
                                
                                TextField("Enter name for merged deck", text: $mergedDeckName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                            }
                            
                            Button {
                                if !mergedDeckName.isEmpty {
                                    let decks = Array(selectedDecks)
                                    databaseManager.mergeDecks(decks[0], decks[1], newName: mergedDeckName)
                                    showingMergeSheet = false
                                    selectedDecks.removeAll()
                                    mergedDeckName = ""
                                }
                            } label: {
                                Text("Merge Decks")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.gradient)
                                    .cornerRadius(12)
                            }
                            .disabled(mergedDeckName.isEmpty)
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .navigationTitle("Merge Decks")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {
                                showingMergeSheet = false
                                selectedDecks.removeAll()
                                mergedDeckName = ""
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDeckNameInput) {
                DeckNameInputView(
                    deckName: $deckName,
                    onSave: {
                        if let url = selectedFolderURL {
                            databaseManager.processFile(at: url, customName: deckName.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        showingDeckNameInput = false
                        selectedFolderURL = nil
                        deckName = ""
                    },
                    onCancel: {
                        showingDeckNameInput = false
                        selectedFolderURL = nil
                        deckName = ""
                    }
                )
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { 
                    databaseManager.errorMessage = nil
                }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: databaseManager.errorMessage) { _, errorMessage in
                if let error = errorMessage {
                    alertMessage = error
                    showingAlert = true
                }
            }
            .overlay {
                if databaseManager.isLoading {
                    LoadingView()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 12) {
                Text("No Flashcard Decks")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add a folder containing images and a database file to create your first flashcard deck")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                showingDocumentPicker = true
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Add Folder")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue.gradient)
                .cornerRadius(12)
            }
        }
    }
    
    private var deckListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(databaseManager.availableDecks) { deck in
                    DeckCardView(deck: deck, databaseManager: databaseManager)
                }
            }
            .padding(.vertical)
        }
    }
}

struct DeckNameInputView: View {
    @Binding var deckName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.stack.badge.person.crop")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("Name Your Flashcard Deck")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Choose a memorable name for your new flashcard deck")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Deck Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter deck name", text: $deckName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSave()
                            }
                        }
                    
                    Text("\(deckName.count)/50 characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        onSave()
                    } label: {
                        Text("Create Deck")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
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
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }
}

struct DeckCardView: View {
    let deck: Deck
    let databaseManager: DatabaseManager
    @State private var showingDeleteAlert = false
    @State private var showingRenameAlert = false
    @State private var newDeckName = ""
    
    var body: some View {
        NavigationLink(destination: GameView(deck: deck, databaseManager: databaseManager)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("\(deck.flashcards.count) cards")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", deck.averageScore))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("\(deck.completedRounds) rounds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(deck.progressPercentage))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: deck.progressPercentage / 100)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(y: 2)
                }
                
                if let lastPlayed = deck.lastPlayedDate {
                    Text("Last played: \(lastPlayed, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button {
                newDeckName = deck.name
                showingRenameAlert = true
            } label: {
                Label("Rename Deck", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete Deck", systemImage: "trash")
            }
        }
        .alert("Rename Deck", isPresented: $showingRenameAlert) {
            TextField("Deck Name", text: $newDeckName)
            Button("Save") {
                if !newDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    var updatedDeck = deck
                    updatedDeck.name = newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
                    databaseManager.updateDeck(updatedDeck)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a new name for this deck")
        }
        .alert("Delete Deck", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                databaseManager.deleteDeck(deck)
            }
        } message: {
            Text("Are you sure you want to delete '\(deck.name)'? This action cannot be undone.")
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Processing Folder...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
        }
    }
}

#Preview {
    DeckListView()
} 
