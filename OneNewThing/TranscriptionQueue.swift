import Foundation
import AVFoundation
// import SwiftData // Replace with CoreData if persistence of queue state is critical beyond UserDefaults
import UIKit // For background task, if implemented fully

// Custom Error for TranscriptionQueue
struct TranscriptionQueueError: Error {
    let originalError: Error
    let isRecoverable: Bool
    var localizedDescription: String {
        return "Transcription failed. Recoverable: \(isRecoverable). Original error: \(originalError.localizedDescription)"
    }
}

class TranscriptionQueue: ObservableObject {
    static let shared = TranscriptionQueue()
    
    @Published var isProcessing = false
    @Published var pendingTranscriptions: [UUID] = [] // Stores recording IDs
    @Published var progress: (current: Int, total: Int) = (0, 0)
    
    // Placeholder for CoreData context if needed for more robust queue persistence
    // private var managedObjectContext: NSManagedObjectContext? 
    
    private let audioRecordingManager = AudioRecordingManager.shared
    private let networkMonitor = NetworkReachabilityMonitor.shared
    private let transcriptionService = TranscriptionService()
    
    private var processingQueue = DispatchQueue(label: "com.onenewthing.TranscriptionProcessingQueue", qos: .userInitiated)
    private let pendingTranscriptionsKey = "pendingTranscriptionIDs"

    private init() {
        // Initialize with a CoreData context if you implement such persistence
        // self.managedObjectContext = ... 
        print("TranscriptionQueue: Initializing...")
        loadPendingTranscriptions()
        
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusChanged), name: .networkStatusChanged, object: nil)
        
        // Optional: Attempt to process queue on app start if conditions are met
        // Consider if this is desired or if processing should only be manually triggered.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { // Delay to allow app to settle
            self.processQueueIfPossible()
        }
        print("TranscriptionQueue: Initialized. Pending items: \(pendingTranscriptions.count)")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .networkStatusChanged, object: nil)
        print("TranscriptionQueue: Deinitialized.")
    }
    
    @objc private func networkStatusChanged(_ notification: Notification) {
        print("TranscriptionQueue: Network status changed notification received.")
        if networkMonitor.isConnected {
            print("TranscriptionQueue: Network connected. Attempting to process queue.")
            processQueueIfPossible()
        } else {
            print("TranscriptionQueue: Network disconnected. Pausing queue processing.")
            // Optionally, update UI or log that queue is paused due to network
        }
    }

    private func loadPendingTranscriptions() {
        print("TranscriptionQueue: Loading pending transcriptions from UserDefaults.")
        if let savedIDs = UserDefaults.standard.array(forKey: pendingTranscriptionsKey) as? [String] {
            self.pendingTranscriptions = savedIDs.compactMap { UUID(uuidString: $0) }
            print("TranscriptionQueue: Loaded \(self.pendingTranscriptions.count) pending transcription IDs.")
        } else {
            print("TranscriptionQueue: No pending transcriptions found in UserDefaults.")
        }
        // Update UI or internal state if needed
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .transcriptionQueueUpdated, object: nil, userInfo: ["queueSize": self.pendingTranscriptions.count])
        }
    }

    private func savePendingTranscriptions() {
        print("TranscriptionQueue: Saving \(pendingTranscriptions.count) pending transcription IDs to UserDefaults.")
        let idsAsString = pendingTranscriptions.map { $0.uuidString }
        UserDefaults.standard.set(idsAsString, forKey: pendingTranscriptionsKey)
        // Update UI or internal state
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .transcriptionQueueUpdated, object: nil, userInfo: ["queueSize": self.pendingTranscriptions.count])
        }
    }

    func enqueue(recordingId: UUID) {
        // Ensure all operations on pendingTranscriptions are thread-safe if accessed from multiple queues
        // For simplicity, assuming updates are dispatched to main or handled by @Published property wrapper correctly
        DispatchQueue.main.async { // Ensure updates to @Published vars are on main thread
            guard !self.pendingTranscriptions.contains(recordingId) else {
                print("TranscriptionQueue: Recording \(recordingId) already in queue.")
                return
            }
            self.pendingTranscriptions.append(recordingId)
            self.savePendingTranscriptions() // This also posts update notification
            print("TranscriptionQueue: Added recording \(recordingId) to queue. New size: \(self.pendingTranscriptions.count)")
            self.processQueueIfPossible()
        }
    }

    func processQueueIfPossible() {
        print("TranscriptionQueue: Checking if queue can be processed. Connected: \(networkMonitor.isConnected), Processing: \(isProcessing), Items: \(pendingTranscriptions.count)")
        guard networkMonitor.isConnected else {
            print("TranscriptionQueue: Cannot process - network disconnected.")
            // Post notification that queue is paused due to network
            DispatchQueue.main.async {
                 NotificationCenter.default.post(name: .transcriptionQueueOffline, object: nil)
            }
            return
        }
        guard !isProcessing else {
            print("TranscriptionQueue: Cannot process - already processing.")
            return
        }
        guard !pendingTranscriptions.isEmpty else {
            print("TranscriptionQueue: Cannot process - queue is empty.")
            return
        }
        
        // Debounce or ensure this isn't called excessively
        // For now, direct call to processQueue.
        processQueue()
    }
    
    private func processQueue() {
        // This function should now be called knowing that network is connected, 
        // not processing, and queue is not empty.
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = (0, self.pendingTranscriptions.count)
            print("TranscriptionQueue: Starting to process \(self.pendingTranscriptions.count) items.")
            NotificationCenter.default.post(name: .transcriptionQueueStarted, object: nil)
        }

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            let group = DispatchGroup()
            var successCount = 0
            var failureCount = 0
            // Make a copy for safe iteration, as pendingTranscriptions might be modified on main thread
            let itemsToProcess = Array(self.pendingTranscriptions) 

            print("TranscriptionQueue: Copied \(itemsToProcess.count) items for this processing batch.")

            for (index, recordingId) in itemsToProcess.enumerated() {
                group.enter()
                
                DispatchQueue.main.async {
                    self.progress = (index + 1, itemsToProcess.count)
                    // Notify that processing has started for this specific recording
                    NotificationCenter.default.post(name: .transcriptionStarted, object: recordingId, userInfo: ["recordingId": recordingId])
                }

                guard let recording = self.audioRecordingManager.getRecording(by: recordingId) else {
                    print("TranscriptionQueue: Error - Recording \(recordingId) not found. Removing from queue.")
                    DispatchQueue.main.async {
                        self.pendingTranscriptions.removeAll { $0 == recordingId }
                        self.savePendingTranscriptions()
                        failureCount += 1
                    }
                    group.leave()
                    continue
                }
                
                print("TranscriptionQueue: Processing item \(index + 1)/\(itemsToProcess.count) - ID: \(recording.id)")

                // The transcribeSingleRecording logic is now simplified as it doesn't need RecordingType from SwiftData
                self.transcribeSingleAudioRecording(recording) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let transcribedText):
                            print("TranscriptionQueue: Successfully transcribed \(recording.id). Text: \(transcribedText.prefix(30))...")
                            self.audioRecordingManager.updateRecordingTranscription(id: recording.id, transcriptionText: transcribedText, originalTranscriptionText: nil) // Assuming direct final text
                            self.pendingTranscriptions.removeAll { $0 == recording.id }
                            successCount += 1
                            NotificationCenter.default.post(name: .singleTranscriptionCompleted, object: recording.id, userInfo: ["success": true])

                        case .failure(let error):
                            print("TranscriptionQueue: Failed to transcribe \(recording.id). Error: \(error.localizedDescription)")
                            failureCount += 1
                            if !error.isRecoverable {
                                // Non-recoverable error (e.g., file invalid, API key bad), remove from queue
                                print("TranscriptionQueue: Non-recoverable error for \(recording.id). Removing from queue.")
                                self.pendingTranscriptions.removeAll { $0 == recording.id }
                            } else {
                                // Recoverable error (e.g. network blip), keep in queue for next attempt
                                print("TranscriptionQueue: Recoverable error for \(recording.id). Will retry later.")
                            }
                            NotificationCenter.default.post(name: .singleTranscriptionCompleted, object: recording.id, userInfo: ["success": false, "error": error.localizedDescription])
                        }
                        self.savePendingTranscriptions() // Save changes to queue (item removed or kept)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.isProcessing = false
                print("TranscriptionQueue: Processing batch completed. Success: \(successCount), Failed: \(failureCount). Remaining: \(self.pendingTranscriptions.count)")
                NotificationCenter.default.post(name: .transcriptionQueueCompleted, object: nil, userInfo: ["successCount": successCount, "failureCount": failureCount, "totalAttempted": itemsToProcess.count])
                
                // If there are still items (e.g., due to recoverable errors or new items added during processing),
                // and network is still good, try processing again after a delay.
                if !self.pendingTranscriptions.isEmpty && self.networkMonitor.isConnected {
                    print("TranscriptionQueue: \(self.pendingTranscriptions.count) items still in queue. Scheduling next attempt.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { // 30-second delay before retrying
                        self.processQueueIfPossible()
                    }
                }
            }
        }
    }

    // Simplified transcription logic for a single recording.
    // The `RecordingType` dependency from VoiceRecorder is removed.
    // We assume the transcription prompt and GPT processing decision are handled by TranscriptionService defaults or passed in if needed.
    private func transcribeSingleAudioRecording(_ recording: AudioRecording, completion: @escaping (Result<String, TranscriptionQueueError>) -> Void) {
        print("TranscriptionQueue: Transcribing single recording ID \(recording.id), URL: \(recording.url)")
        
        guard let audioFileURL = audioRecordingManager.getAudioFileURL(for: recording.url) else {
            print("TranscriptionQueue: Audio file not found for \(recording.url). Marking as non-recoverable.")
            let specificError = NSError(domain: "TranscriptionQueue", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Audio file not found."])
            completion(.failure(TranscriptionQueueError(originalError: specificError, isRecoverable: false)))
            return
        }

        let statusUpdateHandler: (String) -> Void = { message in
            DispatchQueue.main.async {
                // Optional: Update some specific progress for this item if your UI needs it
                print("Status for \(recording.id): \(message)")
                NotificationCenter.default.post(name: .transcriptionProgressUpdate, object: recording.id, userInfo: ["message": message])
            }
        }
        
        // Determine if GPT processing is required. For journal entries, it's generally good.
        let useGPTProcessing = true 
        let gptPrompt = "The following is a voice journal entry. Please format it for readability, correcting any obvious transcription errors, but preserve the original meaning and tone. Do not add any information not present in the original entry. Focus on clarity and natural language."

        transcriptionService.transcribeAudio(
            fileURL: audioFileURL,
            requiresSecondAPICall: useGPTProcessing,
            promptForSecondCall: gptPrompt,
            statusUpdate: statusUpdateHandler
        ) { result in
            switch result {
            case .success(let transcriptionResult):
                completion(.success(transcriptionResult.final))
            case .failure(let error):
                print("TranscriptionQueue: Error during transcription of \(recording.id): \(error.localizedDescription)")
                // Determine if the error is recoverable (e.g., network issues vs. bad API key/file)
                let isRecoverable = self.isErrorRecoverable(error)
                completion(.failure(TranscriptionQueueError(originalError: error, isRecoverable: isRecoverable)))
            }
        }
    }

    // Helper to determine if an error suggests a retry is worthwhile
    private func isErrorRecoverable(_ error: Error) -> Bool {
        if let transcriptionError = error as? TranscriptionService.TranscriptionError {
            switch transcriptionError {
            case .invalidEndpoint, .apiError, .serverError, .noData, .invalidResponse: // Network related or temporary server issues might be recoverable
                // Specific API errors (like auth failure) might not be, but this is a general catch
                return true 
            case .parsingFailed, .fileError: // Issues with file or data parsing are usually not recoverable by retrying the same data
                return false
            }
        }
        // For general network errors (URLError, etc.)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        return false // Default to non-recoverable for unknown errors
    }
    
    // Public function to manually trigger queue processing if needed from UI
    public func attemptProcessPendingTranscriptions() {
        print("TranscriptionQueue: Manual trigger to process pending transcriptions.")
        processQueueIfPossible()
    }
}

// Define RecordingType for `OneNewThing` if it doesn't exist.
// This is a simplified version, not tied to SwiftData like in VoiceRecorder.
// If OneNewThing has its own JournalType or similar, adapt this.
struct RecordingType: Identifiable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var promptForGPT: String? // Optional: Specific instructions for GPT processing
    var requiresSecondAPICall: Bool // Whether to use GPT for refinement

    // Example initializer
    init(id: UUID = UUID(), name: String, iconName: String, promptForGPT: String? = nil, requiresSecondAPICall: Bool = true) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.promptForGPT = promptForGPT
        self.requiresSecondAPICall = requiresSecondAPICall
    }
    
    // Example static type if needed elsewhere
    static var journalEntryExample: RecordingType {
        RecordingType(name: "Journal Entry", 
                      iconName: "book.closed.fill", 
                      promptForGPT: "Format this journal entry for clarity and readability. Correct transcription errors but maintain original meaning.",
                      requiresSecondAPICall: true)
    }
} 