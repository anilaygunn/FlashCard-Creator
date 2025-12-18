import Foundation
import SQLite3
import UniformTypeIdentifiers
import ZIPFoundation

class DatabaseManager: ObservableObject {
    @Published var availableDecks: [Deck] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        loadSavedDecks()
    }
    
    // MARK: - File Processing
    func processFile(at url: URL, customName: String? = nil) {
        print("Processing file at: \(url.path)")
        print("File extension: \(url.pathExtension)")
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Ensure we have access to the security-scoped resource
                let hadAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hadAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let fileExtension = url.pathExtension.lowercased()
                
                switch fileExtension {
                case "apkg":
                    print("Processing Anki package...")
                    try self.processAnkiPackage(url: url, customName: customName)
                case "goodnotes":
                    print("Processing GoodNotes file...")
                    try self.processGoodNotesFile(url: url, customName: customName)
                default:
                    print("Processing as folder...")
                    try self.processFolderContents(at: url, customName: customName)
                }
                
            } catch {
                print("Error processing file: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Error processing file: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Anki Package Processing
    private func processAnkiPackage(url: URL, customName: String? = nil) throws {
        print("Starting Anki package processing...")
        
        // Create a temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        print("Created temp directory at: \(tempDir.path)")
        
        // Extract the .apkg file (it's a ZIP file)
        do {
            try FileManager.default.unzipItem(at: url, to: tempDir)
            print("Successfully extracted Anki package")
        } catch {
            print("Failed to extract Anki package: \(error)")
            throw DatabaseError.invalidAnkiPackage
        }
        
        // List contents of temp directory
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        print("Contents of extracted package:")
        contents.forEach { print($0.lastPathComponent) }
        
        // Find the collection.anki21 file (database)
        let collectionFile = tempDir.appendingPathComponent("collection.anki21")
        guard FileManager.default.fileExists(atPath: collectionFile.path) else {
            print("collection.anki21 file not found")
            throw DatabaseError.invalidAnkiPackage
        }
        
        print("Found collection.anki21 file")
        
        // Process the extracted files
        let deck = try createDeckFromAnkiPackage(
            packageURL: tempDir,
            databaseURL: collectionFile,
            customName: customName
        )
        
        print("Created deck with \(deck.flashcards.count) flashcards")
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDir)
        
        DispatchQueue.main.async {
            if !self.availableDecks.contains(where: { $0.folderPath == deck.folderPath }) {
                self.availableDecks.append(deck)
                self.saveDeck(deck)
                print("Successfully added new deck")
            } else {
                self.errorMessage = "Deck from this file already exists"
                print("Deck already exists")
            }
            self.isLoading = false
        }
    }
    
    private func createDeckFromAnkiPackage(packageURL: URL, databaseURL: URL, customName: String? = nil) throws -> Deck {
        print("Creating deck from Anki package...")
        var db: OpaquePointer?
        var flashcards: [Flashcard] = []
        
        // Open database
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            print("Failed to open database")
            throw DatabaseError.cannotOpenDatabase
        }
        
        defer {
            sqlite3_close(db)
        }
        
        print("Successfully opened database")
        
        // Query for flashcard data from Anki's database schema
        let query = """
            SELECT n.sfld as front, n.flds as fields, m.name as model_name
            FROM notes n
            JOIN cards c ON n.id = c.nid
            JOIN models m ON n.mid = m.id
            """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("Failed to prepare SQL statement")
            throw DatabaseError.cannotPrepareStatement
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        print("Successfully prepared SQL statement")
        
        // Process each row
        var rowCount = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            rowCount += 1
            let front = sqlite3_column_text(statement, 0).map { String(cString: $0) }
            let fields = sqlite3_column_text(statement, 1).map { String(cString: $0) }
            let modelName = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            
            print("Processing row \(rowCount):")
            print("  Front: \(front ?? "nil")")
            print("  Model: \(modelName ?? "nil")")
            
            // Parse the fields based on the model type
            var answer = ""
            if let fields = fields {
                let fieldComponents = fields.components(separatedBy: "\u{1f}")
                print("  Field components count: \(fieldComponents.count)")
                
                if fieldComponents.count > 1 {
                    // Basic model has front and back
                    answer = fieldComponents[1]
                } else if let front = front {
                    // If no back field, use front as answer
                    answer = front
                }
            }
            
            if !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let flashcard = Flashcard(
                    imageName: "", // Anki packages might not have images
                    answer: answer.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                flashcards.append(flashcard)
                print("  Added flashcard with answer: \(answer)")
            }
        }
        
        print("Total rows processed: \(rowCount)")
        print("Total flashcards created: \(flashcards.count)")
        
        guard !flashcards.isEmpty else {
            print("No flashcards found in the package")
            throw DatabaseError.noFlashcardsFound
        }
        
        // Use custom name if provided, otherwise use file name
        let deckName = customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false 
            ? customName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : packageURL.lastPathComponent
        
        let deck = Deck(
            name: deckName,
            folderPath: packageURL.path,
            flashcards: flashcards
        )
        
        return deck
    }
    
    // MARK: - GoodNotes Processing
    private func processGoodNotesFile(url: URL, customName: String? = nil) throws {
        print("Starting GoodNotes file processing...")
        
        // GoodNotes files are actually ZIP files containing PDFs and metadata
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        print("Created temp directory at: \(tempDir.path)")
        
        // Extract the .goodnotes file
        do {
            try FileManager.default.unzipItem(at: url, to: tempDir)
            print("Successfully extracted GoodNotes file")
        } catch {
            print("Failed to extract GoodNotes file: \(error)")
            throw DatabaseError.invalidGoodNotesFile
        }
        
        // List contents of temp directory
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        print("Contents of extracted file:")
        contents.forEach { print($0.lastPathComponent) }
        
        // Try different approaches to find PDFs
        var pdfFiles: [URL] = []
        
        // 1. Look in the root directory
        pdfFiles = try findPDFFiles(in: tempDir)
        print("Found \(pdfFiles.count) PDFs in root directory")
        
        // 2. Look in the media directory
        if pdfFiles.isEmpty {
            let mediaDir = tempDir.appendingPathComponent("media")
            if FileManager.default.fileExists(atPath: mediaDir.path) {
                pdfFiles = try findPDFFiles(in: mediaDir)
                print("Found \(pdfFiles.count) PDFs in media directory")
            }
        }
        
        // 3. Look in the pages directory
        if pdfFiles.isEmpty {
            let pagesDir = tempDir.appendingPathComponent("pages")
            if FileManager.default.fileExists(atPath: pagesDir.path) {
                pdfFiles = try findPDFFiles(in: pagesDir)
                print("Found \(pdfFiles.count) PDFs in pages directory")
            }
        }
        
        // 4. Recursive search as last resort
        if pdfFiles.isEmpty {
            pdfFiles = try findPDFFilesRecursively(in: tempDir)
            print("Found \(pdfFiles.count) PDFs in recursive search")
        }
        
        guard !pdfFiles.isEmpty else {
            print("No PDF files found in the GoodNotes file")
            throw DatabaseError.noFlashcardsFound
        }
        
        var flashcards: [Flashcard] = []
        
        // Process each PDF file
        for (index, pdfFile) in pdfFiles.enumerated() {
            print("Processing PDF file \(index + 1): \(pdfFile.lastPathComponent)")
            
            // Get the page number from the filename or use index
            let pageNumber = pdfFile.lastPathComponent
                .replacingOccurrences(of: "page_", with: "")
                .replacingOccurrences(of: ".pdf", with: "")
            
            let flashcard = Flashcard(
                imageName: pdfFile.lastPathComponent,
                answer: "Page \(pageNumber)"
            )
            flashcards.append(flashcard)
        }
        
        print("Created \(flashcards.count) flashcards")
        
        // Use custom name if provided, otherwise use file name
        let deckName = customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false 
            ? customName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : url.lastPathComponent
        
        let deck = Deck(
            name: deckName,
            folderPath: url.path,
            flashcards: flashcards
        )
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDir)
        
        DispatchQueue.main.async {
            if !self.availableDecks.contains(where: { $0.folderPath == deck.folderPath }) {
                self.availableDecks.append(deck)
                self.saveDeck(deck)
                print("Successfully added new deck")
            } else {
                self.errorMessage = "Deck from this file already exists"
                print("Deck already exists")
            }
            self.isLoading = false
        }
    }
    
    private func findPDFFiles(in directory: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents.filter { $0.pathExtension.lowercased() == "pdf" }
    }
    
    private func findPDFFilesRecursively(in directory: URL) throws -> [URL] {
        var pdfFiles: [URL] = []
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "pdf" {
                pdfFiles.append(fileURL)
            }
        }
        
        return pdfFiles
    }
    
    // MARK: - Folder Selection and Processing
    func processFolderContents(at url: URL, customName: String? = nil) {
        print("Processing folder contents at: \(url.path)")
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Ensure we have access to the security-scoped resource
                let hadAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hadAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                print("Contents of folder:")
                contents.forEach { print($0.lastPathComponent) }
                
                // Find database file
                guard let dbFile = contents.first(where: { $0.pathExtension.lowercased() == "db" }) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "No database file (.db) found in the selected folder"
                        self.isLoading = false
                    }
                    return
                }
                
                // Find images folder
                let imagesFolder = contents.first(where: { url in
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    return isDirectory.boolValue && url.lastPathComponent.lowercased() == "images"
                })
                
                guard let imagesURL = imagesFolder else {
                    DispatchQueue.main.async {
                        self.errorMessage = "No images folder found in the selected folder"
                        self.isLoading = false
                    }
                    return
                }
                
                // Process the deck with custom name if provided
                let deck = try self.createDeckFromFolder(
                    folderURL: url,
                    databaseURL: dbFile,
                    imagesURL: imagesURL,
                    customName: customName
                )
                
                DispatchQueue.main.async {
                    // Check if deck already exists
                    if !self.availableDecks.contains(where: { $0.folderPath == deck.folderPath }) {
                        self.availableDecks.append(deck)
                        self.saveDeck(deck)
                        print("Successfully added new deck with \(deck.flashcards.count) flashcards")
                    } else {
                        self.errorMessage = "Deck from this folder already exists"
                    }
                    self.isLoading = false
                }
                
            } catch {
                print("Error processing folder: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Error processing folder: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Database Processing
    private func createDeckFromFolder(folderURL: URL, databaseURL: URL, imagesURL: URL, customName: String? = nil) throws -> Deck {
        print("Creating deck from folder: \(folderURL.path)")
        print("Database file: \(databaseURL.path)")
        print("Images folder: \(imagesURL.path)")
        
        let flashcards = try readDatabaseAndCreateFlashcards(databaseURL: databaseURL, imagesURL: imagesURL)
        
        guard !flashcards.isEmpty else {
            print("No valid flashcards found in the database")
            throw DatabaseError.noFlashcardsFound
        }
        
        print("Created \(flashcards.count) flashcards")
        
        // Use custom name if provided, otherwise use folder name
        let deckName = customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false 
            ? customName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : folderURL.lastPathComponent
        
        let deck = Deck(
            name: deckName,
            folderPath: folderURL.path,
            flashcards: flashcards
        )
        
        return deck
    }
    
    private func readDatabaseAndCreateFlashcards(databaseURL: URL, imagesURL: URL) throws -> [Flashcard] {
        var db: OpaquePointer?
        var flashcards: [Flashcard] = []
        
        // Open database
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            print("Failed to open database at: \(databaseURL.path)")
            throw DatabaseError.cannotOpenDatabase
        }
        
        defer {
            sqlite3_close(db)
        }
        
        print("Successfully opened database")
        
        // Query for flashcard data
        let query = "SELECT front, back, front_image_file_name, back_image_file_name FROM share_data"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("Failed to prepare SQL statement")
            throw DatabaseError.cannotPrepareStatement
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        // Get list of available images
        let imageFiles = try FileManager.default.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil)
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "heic", "webp"].contains(ext)
            }
        
        print("Found \(imageFiles.count) image files in images folder")
        print("Image files found:")
        imageFiles.forEach { print("  - \($0.lastPathComponent)") }
        
        let imageFileNames = Set(imageFiles.map { $0.lastPathComponent })
        
        // Process each row
        var rowCount = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            rowCount += 1
            let front = sqlite3_column_text(statement, 0).map { String(cString: $0) }
            let back = sqlite3_column_text(statement, 1).map { String(cString: $0) }
            let frontImageFileName = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let backImageFileName = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            
            print("\nProcessing row \(rowCount):")
            print("Front: \(front ?? "nil")")
            print("Back: \(back ?? "nil")")
            print("Front image: \(frontImageFileName ?? "nil")")
            print("Back image: \(backImageFileName ?? "nil")")
            
            // Use front image if available, otherwise back image
            let imageName = frontImageFileName ?? backImageFileName
            let answer = back ?? front ?? "No answer found"
            
            // Check if image exists in the images folder
            if let imageName = imageName {
                print("Checking image: \(imageName)")
                print("Image exists in folder: \(imageFileNames.contains(imageName))")
                
                if imageFileNames.contains(imageName),
                   !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Try to copy the image to persistent storage
                    do {
                        let sourceURL = imagesURL.appendingPathComponent(imageName)
                        _ = try copyImageToPersistentStorage(imageName: imageName, from: sourceURL)
                        
                        let flashcard = Flashcard(
                            imageName: imageName,
                            answer: answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        flashcards.append(flashcard)
                        print("Successfully added flashcard with image: \(imageName) and answer: \(answer)")
                    } catch {
                        print("Failed to copy image to persistent storage: \(error)")
                    }
                } else {
                    print("Skipped row - image not found in folder or empty answer")
                }
            } else {
                print("Skipped row - no image name found")
            }
        }
        
        print("\nTotal rows processed: \(rowCount)")
        print("Total flashcards created: \(flashcards.count)")
        
        return flashcards
    }
    
    // MARK: - Image Persistence
    private func getImagesDirectory() throws -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let imagesDirectory = documentsDirectory.appendingPathComponent("FlashcardImages")
        
        if !fileManager.fileExists(atPath: imagesDirectory.path) {
            try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
        
        return imagesDirectory
    }
    
    func getImageURL(for imageName: String) -> URL? {
        do {
            let imagesDirectory = try getImagesDirectory()
            let imageURL = imagesDirectory.appendingPathComponent(imageName)
            print("Checking image at path: \(imageURL.path)")
            let exists = FileManager.default.fileExists(atPath: imageURL.path)
            print("Image exists: \(exists)")
            return exists ? imageURL : nil
        } catch {
            print("Error getting image URL: \(error)")
            return nil
        }
    }
    
    private func copyImageToPersistentStorage(imageName: String, from sourceURL: URL) throws -> String {
        let imagesDirectory = try getImagesDirectory()
        let destinationURL = imagesDirectory.appendingPathComponent(imageName)
        
        print("Copying image from: \(sourceURL.path)")
        print("To destination: \(destinationURL.path)")
        
        // Only copy if the file doesn't already exist
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("Successfully copied image")
        } else {
            print("Image already exists at destination")
        }
        
        return imageName
    }
    
    // MARK: - Persistence
    func updateDeck(_ updatedDeck: Deck) {
        print("Updating deck: \(updatedDeck.name)")
        
        DispatchQueue.main.async {
            if let index = self.availableDecks.firstIndex(where: { $0.id == updatedDeck.id }) {
                // Ensure all images are in persistent storage
                let updatedFlashcards = updatedDeck.flashcards.compactMap { flashcard -> Flashcard? in
                    guard !flashcard.imageName.isEmpty else { return flashcard }
                    
                    do {
                        let imagesDirectory = try self.getImagesDirectory()
                        let imageURL = imagesDirectory.appendingPathComponent(flashcard.imageName)
                        
                        // If image already exists in persistent storage, use it
                        if FileManager.default.fileExists(atPath: imageURL.path) {
                            return flashcard
                        }
                        
                        // Try to copy from original location if not in persistent storage
                        let originalImageURL = URL(fileURLWithPath: updatedDeck.folderPath).appendingPathComponent(flashcard.imageName)
                        if FileManager.default.fileExists(atPath: originalImageURL.path) {
                            _ = try self.copyImageToPersistentStorage(imageName: flashcard.imageName, from: originalImageURL)
                            return flashcard
                        }
                        
                        print("Warning: Image not found for flashcard: \(flashcard.imageName)")
                        return nil
                    } catch {
                        print("Error handling image for flashcard: \(error)")
                        return nil
                    }
                }
                
                // Create updated deck with only flashcards that have valid images
                let finalDeck = Deck(
                    name: updatedDeck.name,
                    folderPath: updatedDeck.folderPath,
                    flashcards: updatedFlashcards
                )
                
                self.availableDecks[index] = finalDeck
                self.saveDeck(finalDeck)
            }
        }
    }

    private func saveDeck(_ deck: Deck) {
        print("Saving deck: \(deck.name)")
        print("Number of flashcards: \(deck.flashcards.count)")
        
        var savedDecks = loadDecksFromStorage()
        
        // Remove existing deck with same folder path
        savedDecks.removeAll { $0.folderPath == deck.folderPath }
        
        // Copy images to persistent storage
        let updatedFlashcards = deck.flashcards.compactMap { flashcard -> Flashcard? in
            // If flashcard has no image name, keep it
            if flashcard.imageName.isEmpty {
                print("Flashcard has no image name, keeping it")
                return flashcard
            }
            
            do {
                let imagesDirectory = try getImagesDirectory()
                let imageURL = imagesDirectory.appendingPathComponent(flashcard.imageName)
                
                // If image already exists in persistent storage, use it
                if FileManager.default.fileExists(atPath: imageURL.path) {
                    print("Image already exists in persistent storage: \(flashcard.imageName)")
                    return flashcard
                }
                
                // Try to find image in the original folder
                let originalImageURL = URL(fileURLWithPath: deck.folderPath).appendingPathComponent(flashcard.imageName)
                print("Checking original image at: \(originalImageURL.path)")
                
                if FileManager.default.fileExists(atPath: originalImageURL.path) {
                    print("Found original image, copying to persistent storage")
                    _ = try copyImageToPersistentStorage(imageName: flashcard.imageName, from: originalImageURL)
                    return flashcard
                } else {
                    print("Original image not found at: \(originalImageURL.path)")
                    // Keep the flashcard even if image is missing
                    print("Keeping flashcard despite missing image")
                    return flashcard
                }
            } catch {
                print("Error saving image: \(error)")
                // Keep the flashcard even if there's an error
                print("Keeping flashcard despite error")
                return flashcard
            }
        }
        
        print("Updated flashcards count: \(updatedFlashcards.count)")
        
        // Create updated deck with only flashcards that have valid images
        let updatedDeck = Deck(
            name: deck.name,
            folderPath: deck.folderPath,
            flashcards: updatedFlashcards
        )
        
        // Add new deck
        savedDecks.append(updatedDeck)
        
        if let encoded = try? JSONEncoder().encode(savedDecks) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.savedDecks)
            print("Successfully saved deck to UserDefaults")
            
            // Update availableDecks on the main thread
            DispatchQueue.main.async {
                self.availableDecks = savedDecks
            }
        } else {
            print("Failed to encode deck for saving")
        }
    }
    
    private func loadDecksFromStorage() -> [Deck] {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.savedDecks) else {
            print("No saved decks found in UserDefaults")
            return []
        }
        
        do {
            let decks = try JSONDecoder().decode([Deck].self, from: data)
            print("Successfully loaded \(decks.count) decks from storage")
            return decks
        } catch {
            print("Error decoding saved decks: \(error)")
            return []
        }
    }
    
    private func loadSavedDecks() {
        let decks = loadDecksFromStorage()
        print("Loading \(decks.count) saved decks")
        
        // Verify each deck's images
        let verifiedDecks = decks.compactMap { deck -> Deck? in
            let verifiedFlashcards = deck.flashcards.compactMap { flashcard -> Flashcard? in
                guard !flashcard.imageName.isEmpty else { return flashcard }
                
                do {
                    let imagesDirectory = try getImagesDirectory()
                    let imageURL = imagesDirectory.appendingPathComponent(flashcard.imageName)
                    
                    if FileManager.default.fileExists(atPath: imageURL.path) {
                        return flashcard
                    }
                    
                    // Try to copy from original location if not in persistent storage
                    let originalImageURL = URL(fileURLWithPath: deck.folderPath).appendingPathComponent(flashcard.imageName)
                    if FileManager.default.fileExists(atPath: originalImageURL.path) {
                        _ = try copyImageToPersistentStorage(imageName: flashcard.imageName, from: originalImageURL)
                        return flashcard
                    }
                    
                    return nil
                } catch {
                    print("Error verifying image for flashcard: \(error)")
                    return nil
                }
            }
            
            guard !verifiedFlashcards.isEmpty else {
                print("No valid flashcards found for deck: \(deck.name)")
                return nil
            }
            
            return Deck(
                name: deck.name,
                folderPath: deck.folderPath,
                flashcards: verifiedFlashcards
            )
        }
        
        DispatchQueue.main.async {
            self.availableDecks = verifiedDecks.shuffled()
            print("Loaded \(self.availableDecks.count) verified decks")
        }
    }
    
    func deleteDeck(_ deck: Deck) {
        print("Deleting deck: \(deck.name)")
        
        // Remove deck from memory
        DispatchQueue.main.async {
            self.availableDecks.removeAll { $0.id == deck.id }
            
            // Remove deck from UserDefaults
            var savedDecks = self.loadDecksFromStorage()
            savedDecks.removeAll { $0.id == deck.id }
            
            // Save updated decks to UserDefaults
            if let encoded = try? JSONEncoder().encode(savedDecks) {
                UserDefaults.standard.set(encoded, forKey: StorageKeys.savedDecks)
                print("Successfully removed deck from UserDefaults")
            } else {
                print("Failed to encode decks after deletion")
            }
            
            // Clean up associated images
            do {
                let imagesDirectory = try self.getImagesDirectory()
                for flashcard in deck.flashcards {
                    let imageURL = imagesDirectory.appendingPathComponent(flashcard.imageName)
                    if FileManager.default.fileExists(atPath: imageURL.path) {
                        try FileManager.default.removeItem(at: imageURL)
                        print("Deleted image: \(flashcard.imageName)")
                    }
                }
            } catch {
                print("Error cleaning up images: \(error)")
            }
        }
    }
    
    // MARK: - Deck Operations
    func mergeDecks(_ deck1: Deck, _ deck2: Deck, newName: String) {
        print("Merging decks: \(deck1.name) and \(deck2.name)")
        
        // Combine flashcards from both decks
        var mergedFlashcards = deck1.flashcards
        mergedFlashcards.append(contentsOf: deck2.flashcards)
        
        // Remove duplicates based on image name and answer
        mergedFlashcards = Array(Set(mergedFlashcards))
        
        // Create a new unique folder path for the merged deck
        let mergedFolderPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("merged_decks")
            .appendingPathComponent(UUID().uuidString)
            .path
        
        // Create new merged deck with unique path
        let mergedDeck = Deck(
            name: newName,
            folderPath: mergedFolderPath,
            flashcards: mergedFlashcards
        )
        
        // Add merged deck to available decks
        DispatchQueue.main.async {
            self.availableDecks.append(mergedDeck)
            self.saveDeck(mergedDeck)
            print("Successfully merged decks into: \(newName)")
        }
    }
}

// MARK: - Errors
enum DatabaseError: Error, LocalizedError {
    case cannotOpenDatabase
    case cannotPrepareStatement
    case noFlashcardsFound
    case invalidAnkiPackage
    case invalidGoodNotesFile
    
    var errorDescription: String? {
        switch self {
        case .cannotOpenDatabase:
            return "Cannot open database file"
        case .cannotPrepareStatement:
            return "Cannot prepare SQL statement"
        case .noFlashcardsFound:
            return "No valid flashcards found in the file"
        case .invalidAnkiPackage:
            return "Invalid Anki package file"
        case .invalidGoodNotesFile:
            return "Invalid GoodNotes file"
        }
    }
} 
