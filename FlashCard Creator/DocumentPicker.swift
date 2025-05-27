import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    let onFileSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Create custom UTType for .goodnotes if it doesn't exist
        let goodnotesType = UTType(filenameExtension: "goodnotes") ?? UTType.data
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .folder,
            UTType(filenameExtension: "apkg") ?? UTType.data,
            goodnotesType
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Ensure we're on the main queue for UI operations
            DispatchQueue.main.async {
                // Start accessing security-scoped resource
                let hasAccess = url.startAccessingSecurityScopedResource()
                
                if hasAccess {
                    // Store the URL and handle the resource properly
                    self.parent.onFileSelected(url)
                    
                    // Important: Don't stop accessing immediately, let the processing finish
                    // The url will be used in background processing
                } else {
                    print("Failed to access security scoped resource for URL: \(url)")
                }
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async {
                // Handle cancellation if needed
                print("Document picker was cancelled")
            }
        }
    }
} 
