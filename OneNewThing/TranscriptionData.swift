import Foundation

/// Represents the data structure for a completed transcription.
/// This can be associated with an AudioRecording object by its ID.
struct TranscriptionData: Identifiable, Codable, Hashable {
    let id: UUID // This ID should ideally match the UUID of the AudioRecording it belongs to.
    let text: String // The transcribed text.
    let date: Date // Date of transcription completion or association.
    // Add any other relevant metadata, e.g., model used, confidence, language, if available and needed.
    // let language: String?
    // let modelVersion: String?

    init(id: UUID, text: String, date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }
} 