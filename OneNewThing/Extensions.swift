import Foundation
import SwiftUI // Required for Color extension

// Extension for Notification.Name that defines all custom notifications used in the app
extension Notification.Name {
    // Recording & Audio Manager related notifications
    static let recordingsUpdated = Notification.Name("com.onenewthing.recordingsUpdated")
    static let newRecordingAdded = Notification.Name("com.onenewthing.newRecordingAdded") // If used
    static let audioRecordingManagerInitialized = Notification.Name("com.onenewthing.audioRecordingManagerInitialized") // If used

    // Network status notifications
    static let networkStatusChanged = Notification.Name("com.onenewthing.networkStatusChanged")
    static let networkQualityChanged = Notification.Name("com.onenewthing.networkQualityChanged")
    
    // Transcription queue notifications
    static let transcriptionQueueStarted = Notification.Name("com.onenewthing.transcriptionQueueStarted")
    static let transcriptionQueueCompleted = Notification.Name("com.onenewthing.transcriptionQueueCompleted")
    static let transcriptionQueueOffline = Notification.Name("com.onenewthing.transcriptionQueueOffline")
    static let transcriptionQueueNetworkIssue = Notification.Name("com.onenewthing.transcriptionQueueNetworkIssue")
    static let transcriptionQueueUpdated = Notification.Name("com.onenewthing.transcriptionQueueUpdated")
    
    // Individual transcription process notifications
    static let transcriptionStarted = Notification.Name("com.onenewthing.transcriptionStarted") // For a single item
    // static let transcriptionStepCompleted = Notification.Name("com.onenewthing.transcriptionStepCompleted") // If granular steps are notified
    static let transcriptionProgressUpdate = Notification.Name("com.onenewthing.transcriptionProgressUpdate") // For UI updates during transcription
    static let singleTranscriptionCompleted = Notification.Name("com.onenewthing.singleTranscriptionCompleted") // For a single item
}

// Extension for Color to convert to SIMD4 for Metal or other graphics processing if needed.
// If Constants.swift (which also has this) is included and it's the only use case, this might be redundant.
// However, having it here makes Extensions.swift more self-contained if Constants.swift is not used directly.
extension Color {
    /// Converts SwiftUI Color to SIMD4<Float> (RGBA components).
    func toSIMD4() -> SIMD4<Float> {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
}

// Helper to get documents directory URL
// Often useful in file management tasks
func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
} 