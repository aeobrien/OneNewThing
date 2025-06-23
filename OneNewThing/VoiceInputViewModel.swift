import Foundation
import Combine
import AVFoundation // For AVAudioSessionPortDescription if exposing input selection

class VoiceInputViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false // To reflect AudioProcessor's state
    @Published var recordingStatusMessage: String = "Tap microphone to start recording." 
    @Published var errorMessage: String? = nil
    @Published var audioLevel: Float = 0.0 // For visualizer if any
    
    // Access to audio processor and managers
    private let audioProcessor: AudioProcessor
    private let transcriptionQueue = TranscriptionQueue.shared
    private let audioRecordingManager = AudioRecordingManager.shared
    private let networkMonitor = NetworkReachabilityMonitor.shared

    private var currentRecording: AudioRecording? = nil
    private var cancellables = Set<AnyCancellable>()

    // Recording type can be simple string or a more complex type if needed
    private let recordingTypeName = "JournalVoiceInput"

    init() {
        // Initialize AudioProcessor with a generic type name for this context
        self.audioProcessor = AudioProcessor(recordingTypeName: self.recordingTypeName)
        print("VoiceInputViewModel: Initialized with AudioProcessor for type '\(self.recordingTypeName)'.")
        setupSubscribers()
    }

    private func setupSubscribers() {
        print("VoiceInputViewModel: Setting up subscribers for AudioProcessor states.")
        // Subscribe to AudioProcessor's state changes
        audioProcessor.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recordingState in
                self?.isRecording = recordingState
                self?.updateStatusMessage()
                print("VoiceInputViewModel: isRecording state changed to \(recordingState)")
            }
            .store(in: &cancellables)

        audioProcessor.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pausedState in
                self?.isPaused = pausedState
                self?.updateStatusMessage()
                 print("VoiceInputViewModel: isPaused state changed to \(pausedState)")
            }
            .store(in: &cancellables)

        audioProcessor.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        audioProcessor.$processingStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                // We might want to map this to a more user-friendly recordingStatusMessage
                // For now, direct pass-through or selective updates
                if !(self?.isRecording ?? false) && !(self?.isPaused ?? false) && status != "Ready to Record" {
                     // Show processing status if not actively recording/paused (e.g. "Processing...", "Finalizing...")
                    self?.recordingStatusMessage = status
                }
                 print("VoiceInputViewModel: AudioProcessor processingStatus changed to '\(status)'.")
            }
            .store(in: &cancellables)

        audioProcessor.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMsg in
                self?.errorMessage = errorMsg
                if errorMsg != nil {
                    self?.recordingStatusMessage = errorMsg ?? "An error occurred."
                    print("VoiceInputViewModel: AudioProcessor errorMessage: \(errorMsg ?? "Unknown error")")
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to transcription queue updates (optional, for more detailed UI)
        // NotificationCenter.default.publisher(for: .transcriptionQueueUpdated)... 
        // NotificationCenter.default.publisher(for: .transcriptionProgressUpdate)... 
    }

    func toggleRecording() {
        print("VoiceInputViewModel: toggleRecording called. Current state - isRecording: \(isRecording), isPaused: \(isPaused)")
        if isRecording {
            if isPaused {
                resumeRecording()
            } else {
                pauseRecording()
            }
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        guard !isRecording else { 
            print("VoiceInputViewModel: Start recording called, but already recording.")
            return
        }
        print("VoiceInputViewModel: Attempting to start recording.")
        transcribedText = "" // Clear previous transcription
        errorMessage = nil
        recordingStatusMessage = "Starting recording..."
        currentRecording = nil
        audioProcessor.resetState() // Reset audio processor before starting new recording

        audioProcessor.startRecording { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    self.isRecording = true
                    self.isPaused = false // Explicitly set
                    print("VoiceInputViewModel: Recording started successfully.")
                } else {
                    self.isRecording = false
                    self.errorMessage = error?.localizedDescription ?? "Failed to start recording."
                    print("VoiceInputViewModel: Failed to start recording. Error: \(self.errorMessage ?? "Unknown error")")
                }
                self.updateStatusMessage()
            }
        }
    }

    func pauseRecording() {
        guard isRecording && !isPaused else { 
            print("VoiceInputViewModel: Pause called, but not recording or already paused.")
            return 
        }
        print("VoiceInputViewModel: Attempting to pause recording.")
        audioProcessor.pauseRecording()
        // isPaused will be updated by the publisher from AudioProcessor
        // updateStatusMessage() will be called by the publisher sink
    }

    func resumeRecording() {
        guard isRecording && isPaused else { 
            print("VoiceInputViewModel: Resume called, but not recording or not paused.")
            return 
        }
        print("VoiceInputViewModel: Attempting to resume recording.")
        audioProcessor.resumeRecording()
        // isPaused will be updated by the publisher from AudioProcessor
    }

    func stopRecordingAndTranscribe() {
        guard isRecording else { 
            print("VoiceInputViewModel: Stop called, but not recording.")
            if let orphanedRecording = currentRecording, orphanedRecording.transcription == nil {
                // If there's a current recording object that hasn't been transcribed (e.g. app was backgrounded)
                // We might want to queue it here or offer to transcribe it.
                // For now, we assume stop is only called when actively recording.
                 print("VoiceInputViewModel: Found an untranscribed recording. Consider queueing.")
            }
            // If not recording, ensure status is clear
            if !isRecording && !isPaused {
                recordingStatusMessage = "Tap microphone to start."
            }
            return
        }
        print("VoiceInputViewModel: Attempting to stop recording and initiate transcription.")
        recordingStatusMessage = "Finalizing recording..."
        
        audioProcessor.stopRecording { [weak self] recordingObject in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRecording = false // Ensure isRecording is false after stop
                self.isPaused = false
                
                guard let newRecording = recordingObject else {
                    self.errorMessage = "Failed to save recording. Cannot transcribe."
                    self.recordingStatusMessage = "Error saving recording."
                    print("VoiceInputViewModel: Recording object is nil after stopping. Cannot proceed with transcription.")
                    self.updateStatusMessage() // Update to reflect error or idle state
                    return
                }
                self.currentRecording = newRecording
                print("VoiceInputViewModel: Recording stopped. Saved ID: \(newRecording.id). URL: \(newRecording.url). Ready to transcribe.")
                self.transcribeCurrentRecording()
            }
        }
    }

    private func transcribeCurrentRecording() {
        guard let recordingToTranscribe = currentRecording else {
            errorMessage = "No recording available to transcribe."
            recordingStatusMessage = "Error: No recording found."
            print("VoiceInputViewModel: transcribeCurrentRecording called but currentRecording is nil.")
            updateStatusMessage()
            return
        }

        print("VoiceInputViewModel: Preparing to transcribe recording ID: \(recordingToTranscribe.id)")
        recordingStatusMessage = "Preparing for transcription..."

        // Check network status before attempting transcription
        if !networkMonitor.isConnected {
            print("VoiceInputViewModel: Network is not connected. Enqueuing recording ID: \(recordingToTranscribe.id)")
            transcriptionQueue.enqueue(recordingId: recordingToTranscribe.id)
            recordingStatusMessage = "No connection. Will transcribe when online."
            // Update AudioRecordingManager to mark it as not transcribed (it is, by default, but be explicit)
            audioRecordingManager.updateRecordingTranscriptionStatus(id: recordingToTranscribe.id, isTranscribed: false)
            // User feedback about queueing is important here.
            // Transcribed text will remain empty for now.
            self.transcribedText = "" // Or provide a placeholder like "[Transcription will appear when online]"
            self.updateStatusMessage() // Update for queue
            return
        }
        
        // If network is available, proceed with direct transcription
        recordingStatusMessage = "Transcribing..."
        audioProcessor.transcribeRecording(
            recording: recordingToTranscribe,
            statusUpdate: { [weak self] status in // This is the per-step status from TranscriptionService
                DispatchQueue.main.async {
                    self?.recordingStatusMessage = status
                     print("VoiceInputViewModel: Transcription status update - \(status)")
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let text):
                        self.transcribedText = text
                        self.recordingStatusMessage = "Transcription complete!"
                        // audioRecordingManager.updateRecordingTranscription is already called by AudioProcessor
                        print("VoiceInputViewModel: Transcription successful. Text populated. Final status: \(self.recordingStatusMessage)")
                    case .failure(let error):
                        self.errorMessage = "Transcription failed: \(error.localizedDescription)"
                        // If transcription fails, decide if it should be queued or if it's a permanent failure
                        let isRecoverable = self.isErrorRecoverable(error) // Add this helper if not present
                        if isRecoverable && self.networkMonitor.isConnected { // Only queue if seems recoverable and still online (or let queue handle offline)
                             print("VoiceInputViewModel: Transcription failed (recoverable: \(isRecoverable)). Enqueuing ID: \(recordingToTranscribe.id)")
                             self.transcriptionQueue.enqueue(recordingId: recordingToTranscribe.id)
                             self.recordingStatusMessage = "Transcription failed. Will retry later."
                             self.transcribedText = "" // Clear or set placeholder
                        } else {
                             print("VoiceInputViewModel: Transcription failed (recoverable: \(isRecoverable)). Error: \(error.localizedDescription)")
                             self.recordingStatusMessage = "Transcription error."
                             self.transcribedText = "" // Clear text
                        }
                    }
                    // Reset for next recording or idle state
                    // self.currentRecording = nil // Keep current recording until new one starts or viewmodel resets
                    self.updateStatusMessage() // Update based on completion
                }
            }
        )
    }

    private func updateStatusMessage() {
        // This function provides a user-facing status message based on the current state.
        if let errMsg = errorMessage, !isRecording { // Show error if not actively recording and error exists
            recordingStatusMessage = errMsg
            return
        }

        if isRecording {
            if isPaused {
                recordingStatusMessage = "Paused. Tap to resume."
            } else {
                // Format recordingDuration to MM:SS
                let minutes = Int(audioProcessor.recordingDuration) / 60
                let seconds = Int(audioProcessor.recordingDuration) % 60
                recordingStatusMessage = String(format: "Recording... %02d:%02d", minutes, seconds)
            }
        } else {
            // Not recording, check if there was a current recording (implying it just finished or is being processed)
            if currentRecording != nil && transcribedText.isEmpty && transcriptionQueue.pendingTranscriptions.contains(where: {$0 == currentRecording!.id}) {
                 recordingStatusMessage = "Queued. Will transcribe when online."
            } else if currentRecording != nil && transcribedText.isEmpty && audioProcessor.processingStatus.lowercased().contains("transcribing") {
                 // Use the status from audioProcessor if it's actively transcribing this recording
                 // This might be covered by the $processingStatus subscriber already
            } else if !transcribedText.isEmpty {
                recordingStatusMessage = "Tap microphone to record again." // Or "Transcription complete!" for a short while
            } else {
                 // Default idle message
                 recordingStatusMessage = "Tap microphone to start."
            }
        }
        print("VoiceInputViewModel: Updated status message to: '\(recordingStatusMessage)'")
    }
    
    // Helper to determine if an error is recoverable (similar to TranscriptionQueue's one)
    private func isErrorRecoverable(_ error: Error) -> Bool {
        if let transcriptionError = error as? TranscriptionService.TranscriptionError {
            switch transcriptionError {
            case .invalidEndpoint, .apiError, .serverError, .noData, .invalidResponse:
                return true // Network related or temporary server issues
            case .parsingFailed, .fileError:
                return false // Issues with file or data parsing
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        return false // Default to non-recoverable
    }
    
    // Call this if the view is dismissed or done with voice input
    func cleanUp() {
        print("VoiceInputViewModel: Clean up requested.")
        if isRecording {
            // If actively recording, decide whether to auto-stop and transcribe/queue, or discard.
            // For now, let's assume a deliberate stop action is required by the user.
            // If a recording is in progress and view disappears, it might get orphaned.
            // Consider implications for `JournalFlowView` lifecycle.
            print("VoiceInputViewModel: Warning - CleanUp called while recording is active. Recording might be lost if not stopped properly.")
            // audioProcessor.stopRecording { _ in /* handle completion if needed */ } 
        }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        audioProcessor.resetState() // Reset audio processor state
        print("VoiceInputViewModel: Cleaned up subscribers and reset AudioProcessor.")
    }
} 