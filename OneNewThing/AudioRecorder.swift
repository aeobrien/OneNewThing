import Foundation
import AVFoundation
import AVFAudio
import Combine
import SwiftUI

class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder() // ADDED: Singleton instance
    
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var processingStatus: String = "Ready to Record"
    
    // --- Additions for Input Selection ---
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var selectedInput: AVAudioSessionPortDescription? {
        didSet {
            // Attempt to set the preferred input when selectedInput changes
            print("Selected input changed. Attempting to set preferred input.")
            setPreferredInput(selectedInput)
        }
    }
    // --- End Additions ---

    private var audioRecorderInstance: AVAudioRecorder?
    private var recordingURL: URL?
    private var durationTimer: AnyCancellable?
    private var audioLevelTimer: AnyCancellable?
    
    // Store the completion handler passed to stopRecording
    private var stopCompletionHandler: ((URL?) -> Void)?
    // Store the completion handler for startRecording status
    private var startCompletionHandler: ((Bool, Error?) -> Void)?
    
    private var pauseStartTime: Date?
    // Make totalPauseDuration accessible if needed by AudioProcessor
    @Published var totalPauseDuration: TimeInterval = 0 

    private var session: AVAudioSession
    private var currentRecorder: AVAudioRecorder?
    
    // Make init private for singleton pattern
    private override init() {
        session = AVAudioSession.sharedInstance()
        super.init()
        print("AudioRecorder initialized")
        // Fetch available inputs on initialization
        refreshAvailableInputs()
        // Set initial selected input to the current preferred input or the first available one
        if let currentInput = AVAudioSession.sharedInstance().preferredInput {
            self.selectedInput = currentInput
            print("Initial selected input set to preferred input: \(currentInput.portName)")
        } else if let firstInput = availableInputs.first {
            self.selectedInput = firstInput
            print("Initial selected input set to first available input: \(firstInput.portName)")
        } else {
            print("No audio inputs available initially.")
        }
    }

    // --- Additions for Input Selection ---
    /// Refreshes the list of available audio inputs from the shared AVAudioSession.
    func refreshAvailableInputs() {
        print("Refreshing available audio inputs...")
        let session = AVAudioSession.sharedInstance()
        do {
            // --- Optimize: Check Category Before Setting ---
            let desiredCategory = AVAudioSession.Category.playAndRecord
            let desiredOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
            if session.category != desiredCategory || session.categoryOptions != desiredOptions {
                print("refreshAvailableInputs: Current category (\(session.category.rawValue)) or options (\(session.categoryOptions.rawValue)) differ. Setting desired category: \(desiredCategory.rawValue) with options: \(desiredOptions.rawValue)")
                try session.setCategory(desiredCategory, mode: .default, options: desiredOptions)
            } else {
                 print("refreshAvailableInputs: Category and options are already set correctly.")
            }
            // --- End Category Optimization ---
            
            // --- Optimize: Check Active State (Optional but good practice) ---
            // Note: Activating an already active session is generally safe and might be necessary 
            // if system conditions changed, but checking can slightly reduce overhead.
            // However, the docs suggest activating might be needed to detect new devices, so let's keep setActive(true) for now.
            print("refreshAvailableInputs: Ensuring session is active before checking inputs.")
            try session.setActive(true)
            // --- End Active State Optimization ---
            
            // Fetch the available inputs AFTER setting category and activating.
            let currentInputs = session.availableInputs ?? []
            print("Available inputs updated: \(currentInputs.map { $0.portName })")
            
            // Check if the list actually changed before updating the published property
            if self.availableInputs.map({ $0.uid }) != currentInputs.map({ $0.uid }) {
                print("Input list changed. Updating published property.")
                self.availableInputs = currentInputs // This triggers AudioProcessor update via Combine
            } else {
                print("Input list has not changed.")
                // If the list hasn't changed, we likely don't need to re-evaluate the selected input below,
                // unless the preferredInput might have changed externally?
                // For now, let's assume if availableInputs is the same, selectedInput logic doesn't need re-run.
                 // return // Early exit if list is unchanged? Maybe too aggressive. Let's proceed for now.
            }
            
            // --- Optimize: Refine Selected Input Logic --- 
            let currentSelectedUID = selectedInput?.uid
            let isCurrentSelectedStillAvailable = availableInputs.contains(where: { $0.uid == currentSelectedUID })
            var newSelectedInput: AVAudioSessionPortDescription? = selectedInput // Start with current

            if !isCurrentSelectedStillAvailable {
                 if let currentSelected = selectedInput { // Log only if one *was* selected
                      print("Currently selected input '\(currentSelected.portName)' is no longer available or list was empty.")
                 }
                 // Determine fallback: Preferred (if available) -> First Available -> Nil
                 let preferredInput = session.preferredInput
                 let isPreferredInputAvailable = availableInputs.contains(where: { $0.uid == preferredInput?.uid })
                 
                 if let preferred = preferredInput, isPreferredInputAvailable {
                     print("Selecting preferred input as fallback: \(preferred.portName)")
                     newSelectedInput = preferred
                 } else if let firstInput = availableInputs.first {
                     print("Selecting first available input as fallback: \(firstInput.portName)")
                     newSelectedInput = firstInput
                 } else {
                     print("No available inputs to select as fallback.")
                     newSelectedInput = nil
                 }
            } else {
                 print("Currently selected input '\(selectedInput!.portName)' is still available.")
                 // Keep the current selection, so newSelectedInput remains as initially assigned.
            }
            
            // Update the @Published property *only* if the determined selection is different from the current one
            if selectedInput?.uid != newSelectedInput?.uid {
                print("Updating selectedInput from '\(selectedInput?.portName ?? "None")' to '\(newSelectedInput?.portName ?? "None")'.")
                selectedInput = newSelectedInput // This triggers didSet -> setPreferredInput
            } else {
                 print("Selected input remains unchanged: '\(selectedInput?.portName ?? "None")'.")
                 // Explicitly call setPreferredInput IF the system's preferred doesn't match our selected one.
                 // This handles cases where the user changes system default but our app selection should persist.
                 // Or if initial selection failed to set preferredInput before.
                 if session.preferredInput?.uid != selectedInput?.uid {
                     print("System preferred input (\(session.preferredInput?.portName ?? "None")) differs from current selection. Re-applying preference.")
                     setPreferredInput(selectedInput)
                 }
            }
            // --- End Selected Input Optimization --- 
            
        } catch {
            print("Error refreshing, setting category, or activating audio session: \(error.localizedDescription)")
            // Handle error appropriately, maybe log more details
        }
    }

    /// Sets the preferred audio input for the shared AVAudioSession.
    /// - Parameter input: The `AVAudioSessionPortDescription` of the desired input. Pass `nil` to clear the preference.
    private func setPreferredInput(_ input: AVAudioSessionPortDescription?) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredInput(input)
            print("Successfully set preferred input to: \(input?.portName ?? "None")")
        } catch {
            print("Error setting preferred input to \(input?.portName ?? "None"): \(error.localizedDescription)")
            // Optionally, revert the selectedInput state or notify the user
            // For now, we just log the error. The selectedInput state remains as is.
        }
    }
    // --- End Additions ---
    
    func startRecording(completion: @escaping (Bool, Error?) -> Void) {
        print("Requesting record permission")
        // Store the completion handler
        self.startCompletionHandler = completion
        
        if let inputToSet = selectedInput {
            setPreferredInput(inputToSet)
        } else {
             print("Warning: No input selected, using system default.")
        }
        
        AVAudioApplication.requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if allowed {
                    print("Record permission granted.")
                    // Setup recorder and attempt to start
                    do {
                        try self.setupAndStartRecorder()
                        // Call completion with success if setupAndStartRecorder didn't throw
                        self.startCompletionHandler?(true, nil)
                    } catch {
                        // Setup or start failed
                        print("Error during setup or start: \(error.localizedDescription)")
                        self.processingStatus = "Failed to Start: \(error.localizedDescription)"
                        self.isRecording = false // Ensure state is correct
                        self.startCompletionHandler?(false, error) // Report failure
                    }
                } else {
                    print("Microphone access denied")
                    self.processingStatus = "Microphone access denied. Please enable it in Settings."
                    let permissionError = NSError(domain: "AudioRecorder", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
                    self.startCompletionHandler?(false, permissionError) // Report failure
                }
            }
        }
    }

    // Extracted setup and start logic into a throwing function
    private func setupAndStartRecorder() throws {
        print("Setting up and starting recorder...")
        let recordingSession = AVAudioSession.sharedInstance()
        
        // Set Category and Activate Session
        print("Setting audio session category to playAndRecord.")
        try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        print("Activating audio session.")
        try recordingSession.setActive(true)

        // Define Settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100, // Standard sample rate
            AVNumberOfChannelsKey: 1, // Mono recording
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create URL 
        let uniqueID = UUID().uuidString
        let newRecordingURL = getDocumentsDirectory().appendingPathComponent("RecordedAudio_\(uniqueID).m4a")
        
        // Set the current recording URL
        recordingURL = newRecordingURL
        
        // Create Recorder Instance
        print("Creating AVAudioRecorder instance for URL: \(recordingURL!.path)")
        audioRecorderInstance = try AVAudioRecorder(url: recordingURL!, settings: settings)
        audioRecorderInstance?.delegate = self // Set delegate for audioRecorderDidFinishRecording
        audioRecorderInstance?.isMeteringEnabled = true
        
        // Attempt to Start Recording Hardware
        print("Starting recorder instance...")
        let success = audioRecorderInstance?.record()
        
        if success == true {
            print("Recorder instance started successfully.")
            self.processingStatus = "Recording..." // Update status on success
            self.isRecording = true
            self.isPaused = false
            self.startTimers() // Start timers only if recording actually started
        } else {
            print("Failed to start recorder instance.")
            // If record() returns false, it often means the session is not set up correctly or hardware issues.
            // An error might have been thrown by AVAudioRecorder init, but record() itself can also fail.
            // Ensure this state is clearly communicated back.
            isRecording = false // Ensure recording state is false
            isPaused = false
            processingStatus = "Failed to Start Recording Hardware"
            // Create an error to pass back
            let startError = NSError(domain: "AudioRecorder", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio recording hardware."])
            throw startError // Throw the error to be caught by the calling startRecording function
        }
    }

    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        print("Pausing recording...")
        audioRecorderInstance?.pause()
        pauseStartTime = Date() // Record when pause started
        isPaused = true
        processingStatus = "Paused"
        stopTimers(shouldInvalidateDuration: false) // Stop audio level timer, keep duration
    }

    func resumeRecording() {
        guard isRecording && isPaused else { return }
        print("Resuming recording...")
        if let pauseStart = pauseStartTime {
            let pauseDuration = Date().timeIntervalSince(pauseStart)
            totalPauseDuration += pauseDuration // Accumulate pause duration
            pauseStartTime = nil // Reset pause start time
        }
        audioRecorderInstance?.record()
        isPaused = false
        processingStatus = "Recording..."
        startTimers() // Resume timers
    }
    
    // Modified stopRecording to accept a completion handler
    func stopRecording(completion: @escaping (URL?) -> Void) {
        print("Stopping recording...")
        // Store the completion handler to be called after recording stops and finalizes
        self.stopCompletionHandler = completion
        
        // Check if actually recording
        guard audioRecorderInstance != nil, isRecording else {
            print("Not recording or recorder not initialized. No action taken.")
            self.stopCompletionHandler?(nil) // Call completion with nil as no URL generated
            self.stopCompletionHandler = nil // Clear handler
            return
        }

        if isPaused, let pauseStart = pauseStartTime {
            let finalPauseDuration = Date().timeIntervalSince(pauseStart)
            totalPauseDuration += finalPauseDuration
            print("Recording was paused. Added final pause duration: \(finalPauseDuration)s. Total pause: \(totalPauseDuration)s")
        }
        
        audioRecorderInstance?.stop() // This will trigger audioRecorderDidFinishRecording
        isRecording = false
        isPaused = false
        processingStatus = "Stopping..."
        stopTimers(shouldInvalidateDuration: true) // Stop all timers and reset duration
        // The actual file finalization and completion handler call happens in audioRecorderDidFinishRecording
    }
    
    private func startTimers() {
        print("Starting timers (duration and audio level)...")
        // Duration Timer
        durationTimer?.cancel() // Cancel existing timer if any
        durationTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.recordingDuration = self.audioRecorderInstance?.currentTime ?? 0
            }
        
        // Audio Level Timer
        audioLevelTimer?.cancel() // Cancel existing timer if any
        audioLevelTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isRecording, !self.isPaused else {
                    self?.audioLevel = 0.0 // Reset audio level if not recording/paused
                    return
                }
                self.audioRecorderInstance?.updateMeters()
                // Corrected way to get average power and convert to a 0-1 range
                let averagePower = self.audioRecorderInstance?.averagePower(forChannel: 0) ?? -160.0 // Default to very low if nil
                let minDb: Float = -60.0 // Adjusted based on typical microphone sensitivity and noise floor
                
                var linearLevel: Float = 0.0
                if averagePower < minDb {
                    linearLevel = 0.0
                } else if averagePower >= 0.0 {
                    linearLevel = 1.0
                } else {
                    // This formula provides a somewhat linear scale for dB values above minDb
                    linearLevel = pow(10, (0.05 * averagePower)) 
                    // Clamp to ensure it's within 0 to 1
                    linearLevel = max(0.0, min(1.0, linearLevel))
                }
                self.audioLevel = linearLevel
            }
    }

    private func stopTimers(shouldInvalidateDuration: Bool = true) {
        print("Stopping timers. Invalidate duration: \(shouldInvalidateDuration)")
        durationTimer?.cancel()
        audioLevelTimer?.cancel()
        if shouldInvalidateDuration {
            // Reset recording duration when stopping completely, not on pause
            recordingDuration = 0
        }
        audioLevel = 0.0 // Reset audio level
    }
    
    func reset() {
        print("AudioRecorder: Resetting state.")
        if isRecording {
            // If recording, stop it first (without calling completion that might be set for a normal stop)
            audioRecorderInstance?.stop()
        }
        stopTimers(shouldInvalidateDuration: true)
        isRecording = false
        isPaused = false
        recordingDuration = 0
        audioLevel = 0.0
        totalPauseDuration = 0 // Reset total pause duration
        pauseStartTime = nil
        processingStatus = "Ready to Record"
        audioRecorderInstance = nil
        recordingURL = nil
        // Clear completion handlers to prevent unintended calls
        stopCompletionHandler = nil
        startCompletionHandler = nil
        
        // Optionally, re-configure audio session or refresh inputs if needed upon a full reset
        // configureAudioSession() // This might be too aggressive if session is globally managed
        // refreshAvailableInputs()
        print("AudioRecorder: State has been reset.")
    }
    
    // Helper to get documents directory URL
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("audioRecorderDidFinishRecording called. Success: \(flag)")
        if flag {
            print("Recording finished successfully. URL: \(recorder.url.path)")
            // Call the stored completion handler with the URL
            stopCompletionHandler?(recorder.url)
        } else {
            print("Recording failed or was stopped before completion (e.g., by an interruption).")
            // Call completion with nil as recording was not successful
            stopCompletionHandler?(nil)
        }
        // Clear the handler after calling it
        stopCompletionHandler = nil
        
        // Reset recording state variables
        // isRecording and isPaused should already be false if stopRecording was called.
        // Timers are also stopped in stopRecording.
        // We might want to update status here too.
        DispatchQueue.main.async {
            self.processingStatus = flag ? "Finished" : "Failed/Interrupted"
            // Ensure isRecording is false
            self.isRecording = false
            self.isPaused = false
        }
        
        // According to Apple docs, good practice to release shared audio session if not immediately needed
        // However, for an app that might quickly re-record, keeping it active might be better.
        // For now, let's not deactivate it here, assuming it will be managed by app lifecycle or next recording.
        // do {
        //     try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        //     print("Audio session deactivated after recording.")
        // } catch {
        //     print("Error deactivating audio session: \(error.localizedDescription)")
        // }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Audio recording encode error: \(error.localizedDescription)")
            processingStatus = "Encoding Error"
        } else {
            print("Audio recording encode error: Unknown error.")
            processingStatus = "Unknown Encoding Error"
        }
        // Reset state or handle error as needed
        isRecording = false
        isPaused = false
        stopTimers()
        // Call completion with nil as recording failed
        stopCompletionHandler?(nil)
        stopCompletionHandler = nil
    }
}

// Helper struct for permissions, if you want to expand permission handling
// This is more for SwiftUI views to observe
class AudioPermissionManager: ObservableObject {
    @Published var permissionGranted: Bool = false

    init() {
        checkPermission()
    }

    func checkPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionGranted = true
        case .denied:
            permissionGranted = false
        case .undetermined:
            permissionGranted = false // Will be false until user responds to prompt
        @unknown default:
            permissionGranted = false
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                completion(granted)
            }
        }
    }
}
