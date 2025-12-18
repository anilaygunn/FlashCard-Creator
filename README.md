# FlashCard Creator

FlashCard Creator is a modern iOS application built with SwiftUI that empowers you to create, manage, and master your flashcard decks. Whether you're learning a new language or preparing for an exam, FlashCard Creator provides a seamless experience for organizing your study materials and tracking your progress.

## Features

- **Custom Deck Import**: Easily import flashcard decks from local folders containing images and database files.
- **Deck Management**: Rename, delete, and organize your decks with a simple and intuitive interface.
- **Deck Merging**: Combine two existing decks into a new, larger deck to consolidate your study topics.
- **Smart Study Mode**: Test your knowledge with an interactive flashcard game.
  - View questions (images) and reveal answers.
  - Mark cards as "Correct" or "Wrong" to track performance.
- **Progress Tracking**:
  - **Session Scores**: See how well you performed in your current study session.
  - **Deck Statistics**: Track total rounds, average scores, and completion percentage for each deck.
  - **Last Played**: Keep track of when you last studied each deck.
- **Clean & Modern UI**: A beautiful, user-friendly interface designed with SwiftUI.

## Screenshots

*(Add screenshots here to showcase your app's various views, such as the Deck List, Game View, and Results Screen.)*

## Requirements

- **iOS**: 17.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+

## Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/yourusername/flashcard-creator.git
    ```
2.  **Open the project**:
    Navigate to the project folder and open `FlashCard Creator.xcodeproj` in Xcode.
3.  **Build and Run**:
    Select your target simulator or connected iOS device and press `Cmd + R` to run the app.

## Usage

1.  **Adding a Deck**:
    - Tap the **+ (Plus)** button on the main screen.
    - Select a folder from your device files that contains your flashcard data (images and database).
    - Give your new deck a name.
2.  **Merging Decks**:
    - If you have at least two decks, tap the **Merge** icon (rectangle stack with plus).
    - Select exactly two decks you wish to combine.
    - Enter a name for the new merged deck and confirm.
3.  **Studying**:
    - Tap on any deck to enter the **Game View**.
    - Look at the image/question and guess the answer.
    - Tap **Show Answer** to reveal the correct answer.
    - Mark your response as **Correct** or **Wrong**.
    - View your detailed results at the end of the session.

## Technologies Used

- **SwiftUI**: For the declarative user interface.
- **ZIPFoundation**: For handling file operations if applicable.
- **FileManager**: For local data persistence and file management.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
