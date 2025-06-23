import SwiftUI
import AVFoundation
import Combine
// import AudioKit // AudioKit might not be needed in OneNewThing
// import SwiftData // SwiftData might not be needed here, or will be different

// Definition for AudioSegment, ensure it's used or remove if not
struct AudioSegment: Identifiable {
    let id: UUID
    let index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let url: URL
    var overlapRange: Range<String.Index>?
    
    init(index: Int, startTime: TimeInterval, endTime: TimeInterval, text: String, url: URL) {
        self.id = UUID()
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.url = url
    }
}

class AudioProcessor: ObservableObject {
    let MAX_RECORDING_DURATION: TimeInterval = 900 // 15 minutes in seconds
    @Published var originalDuration: TimeInterval = 0
    @Published var processedDuration: TimeInterval = 0
    @Published var originalFileSize: Int64 = 0
    @Published var processedFileSize: Int64 = 0
    @Published var transcriptionProgress: String = ""
    @Published var isTranscriptionComplete: Bool = false
    @Published var segments: [AudioSegment] = [] // Consider if this is needed
    @Published var rawSegments: [String] = [] // Consider if this is needed
    @Published var processingStatus: String = "Ready to Record"
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var transcription: String = ""
    // @Published var sampleBuffer: SampleBuffer = SampleBuffer(samples: []) // SampleBuffer might not be needed
    // @Published var processedSampleBuffer: SampleBuffer = SampleBuffer(samples: []) // SampleBuffer might not be needed
    @Published var sampleRate: Double = 44100.0
    
    @Published var originalAudioURL: URL?
    @Published var processedAudioURL: URL?
    
    @Published var errorMessage: String?
    @Published var totalPauseDuration: TimeInterval = 0
    
    @Published var isProcessingComplete: Bool = false
    @Published var delayedTranscription: String = ""
    
    @Published var currentlyTranscribingID: UUID?
    
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var selectedInput: AVAudioSessionPortDescription? {
        didSet {
            if audioRecorder.selectedInput?.uid != selectedInput?.uid {
                print("AudioProcessor: selectedInput changed via Passthrough. Forwarding to audioRecorder: \(selectedInput?.portName ?? "None")")
                audioRecorder.selectedInput = selectedInput
            }
        }
    }
    
    // This will be a generic string for the type, not a complex object from VoiceRecorder
    let recordingTypeName: String 
    
    var processingCompletionHandler: (() -> Void)?
    private var audioRecorder: AudioRecorder
    private var inputCancellable: AnyCancellable?
    private var audioLevelCancellable: AnyCancellable?
    private var recordingTimer: Timer?
    private let transcriptionService = TranscriptionService()
    // private let textStitcher = TextStitcher() // TextStitcher might not be needed
    
    // Silence detection parameters - keep if silence stripping is used
    private let silenceThreshold: Float = -40.0
    private let silenceDuration: TimeInterval = 0.5
    private let segmentDuration: TimeInterval = 900 // Max segment for transcription
    private let overlapDuration: TimeInterval = 5.0 // Overlap for segmented transcription if used
    
    private var pauseStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private let audioRecordingManager = AudioRecordingManager.shared
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // Simplified Initializer for OneNewThing
    init(recordingTypeName: String = "JournalEntry") { // Default type name
        self.recordingTypeName = recordingTypeName
        self.audioRecorder = AudioRecorder.shared
        print("AudioProcessor initialized for type '\(recordingTypeName)' using AudioRecorder.shared.")
        subscribeToRecorderInputs()
    }
    
    private func subscribeToRecorderInputs() {
        print("AudioProcessor: Subscribing to audioRecorder's input properties.")
        audioRecorder.$availableInputs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inputs in
                if self?.availableInputs.map({$0.uid}) != inputs.map({$0.uid}) {
                    self?.availableInputs = inputs
                }
            }
            .store(in: &cancellables)

         audioRecorder.$selectedInput
             .receive(on: DispatchQueue.main)
             .sink { [weak self] recorderSelection in
                 if self?.selectedInput?.uid != recorderSelection?.uid {
                     self?.selectedInput = recorderSelection
                 }
             }
             .store(in: &cancellables)

        self.availableInputs = audioRecorder.availableInputs
        self.selectedInput = audioRecorder.selectedInput
        print("AudioProcessor: Initial availableInputs: \(self.availableInputs.map { $0.portName }), Initial selectedInput: \(self.selectedInput?.portName ?? "None")")
    }
    
    private func calculateDurationReduction() -> Int {
        guard originalDuration > 0 else { return 0 }
        return Int(100 - (processedDuration / originalDuration * 100))
    }
    
    func notifyProcessingComplete() {
        isProcessingComplete = true
        processingCompletionHandler?()
    }
    
    func startRecording(completion: @escaping (Bool, Error?) -> Void) {
        print("AudioProcessor: startRecording called.")
        self.recordingDuration = 0
        self.totalPauseDuration = 0
        self.errorMessage = nil
        self.transcription = ""
        self.isTranscriptionComplete = false
        self.isProcessingComplete = false
        self.currentlyTranscribingID = nil
        self.originalDuration = 0
        self.processedDuration = 0
        self.originalFileSize = 0
        self.processedFileSize = 0
        self.processingStatus = "Initializing..."

        audioRecorder.startRecording { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    self.processingStatus = "Recording..."
                    self.isRecording = true
                    self.isPaused = false
                    self.startRecordingTimer()
                    self.subscribeToAudioLevel()
                    print("AudioProcessor: Recording started successfully.")
                    completion(true, nil)
                } else {
                    self.processingStatus = "Failed to Start Recording."
                    self.isRecording = false 
                    self.errorMessage = error?.localizedDescription ?? "Could not start recording. Please check microphone permissions."
                    print("AudioProcessor: Failed to start recording. Error: \(self.errorMessage ?? "Unknown error")")
                    completion(false, error)
                }
            }
        }
    }
    
    public func resumeRecording() {
        print("Resuming recording...")
        audioRecorder.resumeRecording()
        if let pauseStart = pauseStartTime {
            let pauseDuration = Date().timeIntervalSince(pauseStart)
            totalPauseDuration += pauseDuration
            pauseStartTime = nil
            print("Resumed recording. Pause duration: \(pauseDuration), Total pause duration: \(totalPauseDuration)")
        }
        isPaused = false
        processingStatus = "Recording..."
        startRecordingTimer()
        subscribeToAudioLevel()
        print("Recording resumed")
    }

    public func pauseRecording() {
        print("Pausing recording...")
        audioRecorder.pauseRecording()
        pauseStartTime = Date()
        isPaused = true
        processingStatus = "Recording Paused"
        stopRecordingTimer()
        unsubscribeFromAudioLevel()
        if let startTime = pauseStartTime {
             print("Recording paused at \(startTime)")
        }
    }

    func stopRecording(completion: @escaping (AudioRecording?) -> Void) {
        print("AudioProcessor: Stopping recording...")
        if isPaused, let pauseStart = pauseStartTime {
            let finalPauseDuration = Date().timeIntervalSince(pauseStart)
            totalPauseDuration += finalPauseDuration
            print("AudioProcessor: Added final pause duration: \(finalPauseDuration), Total pause duration: \(totalPauseDuration)")
        }
        
        self.processingStatus = "Finalizing recording..."
        
        audioRecorder.stopRecording { [weak self] url in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(nil)
                    return
                }
                self.isRecording = false
                self.isPaused = false
                self.stopRecordingTimer()
                self.unsubscribeFromAudioLevel()
                
                guard let recordedURL = url else {
                    self.processingStatus = "Failed to finalize recording."
                    self.errorMessage = "Recording URL not found after stopping."
                    print("AudioProcessor: Error - Recording URL is nil after stopping.")
                    completion(nil)
                    return
                }
                
                self.originalAudioURL = recordedURL
                self.originalDuration = self.recordingDuration // Capture final duration
                print("AudioProcessor: Recording stopped. Original URL: \(recordedURL.path), Original Duration: \(self.originalDuration)s")
                
                // For OneNewThing, we might not need complex silence stripping initially.
                // We can directly use the original recording for transcription.
                // If silence stripping is a must, the logic from VoiceRecorder needs to be carefully adapted.
                // For now, let's assume no silence stripping or use a simplified path.

                self.processingStatus = "Processing audio..."
                // Simulate processing if no actual processing like silence stripping is done.
                // In a real scenario, this is where you'd call stripSilenceAndProcess or similar.
                // For this integration, we'll treat the original as the processed one for simplicity.
                self.processedAudioURL = recordedURL 
                self.processedDuration = self.originalDuration
                // Get file sizes
                do {
                    let originalAttributes = try FileManager.default.attributesOfItem(atPath: recordedURL.path)
                    self.originalFileSize = originalAttributes[.size] as? Int64 ?? 0
                    self.processedFileSize = self.originalFileSize // Same if no processing
                } catch {
                    print("Error getting file attributes: \(error.localizedDescription)")
                }
                
                print("AudioProcessor: Audio processing complete (no silence stripping for now). Processed URL: \(self.processedAudioURL?.path ?? "N/A"), Processed Duration: \(self.processedDuration)s")
                
                let newRecording = self.audioRecordingManager.saveRecording(
                    url: self.processedAudioURL!, // Use processed (which is original here)
                    recordingTypeName: self.recordingTypeName,
                    originalDuration: self.originalDuration,
                    processedDuration: self.processedDuration,
                    reductionPercentage: self.calculateDurationReduction(),
                    totalPauseDuration: self.totalPauseDuration,
                    question: nil // JournalFlowView might set this later if needed
                )
                self.currentlyTranscribingID = newRecording.id
                
                print("AudioProcessor: Saved recording metadata. ID: \(newRecording.id)")
                self.processingStatus = "Ready for Transcription"
                self.isProcessingComplete = true
                self.notifyProcessingComplete()
                completion(newRecording) // Return the saved AudioRecording object
            }
        }
    }
    
    func transcribeRecording(
        recording: AudioRecording,
        statusUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let audioURL = audioRecordingManager.getAudioFileURL(for: recording.url) else {
            let error = NSError(domain: "AudioProcessor", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Audio file not found for transcription."])
            print("Error: Audio file URL not found for recording \(recording.id)")
            statusUpdate("Error: Audio file not found.")
            completion(.failure(error))
            return
        }
        
        print("AudioProcessor: Starting transcription for recording ID \(recording.id) at URL \(audioURL.path)")
        self.currentlyTranscribingID = recording.id
        self.isTranscriptionComplete = false
        self.transcriptionProgress = "Starting transcription..."
        statusUpdate("Preparing for transcription...")

        // For OneNewThing, we don't need the complex RecordingType object from VoiceRecorder
        // We can pass false for `requiresSecondAPICall` if we just want raw Whisper output.
        // Or true if we want it processed by GPT (which was the original VoiceRecorder behavior).
        // The prompt for the second call can be customized if needed.
        
        let requiresGPTProcessing = true // Set this based on whether you want GPT refinement
        let gptPrompt = "You are a helpful assistant. The following is a voice journal entry. Please format it for readability, correcting any obvious transcription errors, but preserve the original meaning and tone. Do not add any information not present in the original. Focus on clarity and natural language."

        transcriptionService.transcribeAudio(
            fileURL: audioURL,
            requiresSecondAPICall: requiresGPTProcessing, // Use GPT for refinement
            promptForSecondCall: gptPrompt, 
            statusUpdate: { [weak self] updateMessage in
                DispatchQueue.main.async {
                    self?.transcriptionProgress = updateMessage
                    statusUpdate(updateMessage) // Forward to the view
                    print("Transcription Status Update (ID: \(recording.id)): \(updateMessage)")
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.currentlyTranscribingID = nil // Clear when done
                    switch result {
                    case .success(let transcriptionResult):
                        let finalText = transcriptionResult.final
                        self.transcription = finalText
                        self.isTranscriptionComplete = true
                        self.transcriptionProgress = "Transcription complete!"
                        self.audioRecordingManager.updateRecordingTranscription(
                            id: recording.id,
                            transcriptionText: finalText,
                            originalTranscriptionText: transcriptionResult.original // Store original if available
                        )
                        print("AudioProcessor: Transcription successful for ID \(recording.id). Text: '\(finalText.prefix(50))...'")
                        statusUpdate("Transcription complete!")
                        completion(.success(finalText))
                        
                    case .failure(let error):
                        self.transcriptionProgress = "Transcription failed: \(error.localizedDescription)"
                        self.errorMessage = "Transcription failed: \(error.localizedDescription)"
                        self.isTranscriptionComplete = false // Explicitly set to false
                        // Update status in manager to reflect transcription was attempted but failed (isTranscribed remains false)
                        self.audioRecordingManager.updateRecordingTranscription(id: recording.id, transcriptionText: nil)
                        print("AudioProcessor: Transcription failed for ID \(recording.id). Error: \(error.localizedDescription)")
                        statusUpdate("Transcription failed.")
                        completion(.failure(error))
                    }
                }
            }
        )
    }

    private func startRecordingTimer() {
        stopRecordingTimer() // Ensure any existing timer is stopped
        // Initialize recordingDuration to what audioRecorder reports if it's already running (e.g. resume)
        // However, audioRecorder.recordingDuration is reset in start/resume of AudioRecorder itself.
        // So, AudioProcessor's recordingDuration should also be managed carefully.
        // For simplicity, let's assume recordingDuration in AudioProcessor starts from 0 on new record/resume.
        
        // If resuming, audioRecorder.recordingDuration would be the point to continue from.
        // But our timer adds to *this* class's recordingDuration.
        // Let audioRecorder manage its own internal duration. This timer is for UI display.
        
        print("AudioProcessor: Starting recording timer. Current self.recordingDuration: \(self.recordingDuration)")

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording, !self.isPaused else { return }
            // Increment internal duration. AudioRecorder's duration is the source of truth for the file.
            self.recordingDuration += 0.1 
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        print("AudioProcessor: Recording timer stopped. Final self.recordingDuration: \(self.recordingDuration)")
    }

    private func subscribeToAudioLevel() {
        unsubscribeFromAudioLevel() // Ensure no duplicate subscriptions
        audioLevelCancellable = audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
    }

    private func unsubscribeFromAudioLevel() {
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil
    }
    
    func resetState() {
        print("AudioProcessor: Resetting state.")
        stopRecordingTimer()
        unsubscribeFromAudioLevel()
        
        originalDuration = 0
        processedDuration = 0
        originalFileSize = 0
        processedFileSize = 0
        transcriptionProgress = ""
        isTranscriptionComplete = false
        segments = []
        rawSegments = []
        processingStatus = "Ready to Record"
        isRecording = false
        isPaused = false
        recordingDuration = 0
        audioLevel = 0.0
        transcription = ""
        originalAudioURL = nil
        processedAudioURL = nil
        errorMessage = nil
        totalPauseDuration = 0
        isProcessingComplete = false
        delayedTranscription = ""
        currentlyTranscribingID = nil
        
        // Do not reset audioRecorder here, it's a shared instance.
        // audioRecorder.reset() // If AudioRecorder had a reset method
    }
}

// Minimal SampleBuffer struct if needed, or remove if AudioKit/complex processing is excluded
// struct SampleBuffer {
//     var samples: [Float]
// }
 