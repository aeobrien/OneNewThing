import Foundation

// Define the legacy Transcription struct for decoding the old file
// We place it outside the class so it doesn't conflict if TranscriptionManager is still compiled
private struct LegacyTranscription: Codable {
    let recordingId: UUID
    let text: String
    // Add other fields if they exist in the JSON, even if not used, to ensure decoding works
    // let id: UUID? // Optional if it might be missing in some old entries
    // let date: Date? // Optional if it might be missing
}

class AudioRecordingManager: ObservableObject {
    static let shared = AudioRecordingManager()
    
    @Published var recordings: [AudioRecording] = []
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let metadataURL: URL
    private let legacyMetadataURL: URL // Path for the old transcription file
    
    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        metadataURL = documentsDirectory.appendingPathComponent("recordings_metadata.json")
        legacyMetadataURL = documentsDirectory.appendingPathComponent("transcriptions_metadata.json") // Define legacy path
        loadRecordings() // Load first to have data available for migration check
        migrateTranscriptionsIfNeeded() // Run migration after initial load
        print("AudioRecordingManager initialized. Documents directory: \(documentsDirectory.path)")
    }
    
    func saveRecording(
        url: URL,
        recordingTypeName: String,
        originalDuration: TimeInterval? = nil,
        processedDuration: TimeInterval? = nil,
        reductionPercentage: Int? = nil,
        totalPauseDuration: TimeInterval? = nil,
        question: String? = nil
    ) -> AudioRecording {
        let newRecording = AudioRecording(
            id: UUID(),
            url: url.lastPathComponent,
            recordingTypeName: recordingTypeName,
            isTranscribed: false,
            date: Date(),
            originalDuration: originalDuration,
            processedDuration: processedDuration,
            reductionPercentage: reductionPercentage,
            totalPauseDuration: totalPauseDuration,
            question: question,
            transcription: nil,
            originalTranscription: nil
        )
        
        if let existingIndex = recordings.firstIndex(where: { $0.url == newRecording.url }) {
            print("Updating existing recording metadata (excluding transcription): \(recordings[existingIndex].id)")
            var updatedRecording = recordings[existingIndex]
            updatedRecording.recordingTypeName = newRecording.recordingTypeName
            updatedRecording.originalDuration = newRecording.originalDuration
            updatedRecording.processedDuration = newRecording.processedDuration
            updatedRecording.reductionPercentage = newRecording.reductionPercentage
            updatedRecording.totalPauseDuration = newRecording.totalPauseDuration
            updatedRecording.question = newRecording.question
            updatedRecording.date = recordings[existingIndex].date
            updatedRecording.id = recordings[existingIndex].id
            
            recordings[existingIndex] = updatedRecording
            saveRecordingsMetadata()
            return updatedRecording
        } else {
            recordings.append(newRecording)
            print("Saved new recording metadata (transcription pending): \(newRecording.id)")
            saveRecordingsMetadata()
            return newRecording
        }
    }
    private func saveRecordingsMetadata() {
        // Log details before saving
        let transcribedCount = recordings.filter { $0.isTranscribed }.count
        let untranscribedCount = recordings.count - transcribedCount
        let withTextCount = recordings.filter { $0.transcription != nil && !$0.transcription!.isEmpty }.count
        print("💾 Saving metadata: Total=\(recordings.count), Transcribed=\(transcribedCount), Untranscribed=\(untranscribedCount), WithText=\(withTextCount)")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Make it readable
            let data = try encoder.encode(recordings)
            try data.write(to: metadataURL, options: [.atomic]) // Use atomic write for safety
            print("✅ Successfully saved recordings metadata to \(metadataURL.path)")
        } catch {
            print("❌ Error saving recordings metadata: \(error.localizedDescription)")
            // Consider propagating this error or showing an alert
        }
    }

    func updateRecordingTranscriptionStatus(id: UUID, isTranscribed: Bool) {
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            recordings[index].isTranscribed = isTranscribed
            saveRecordingsMetadata()
            print("Updated recording transcription status: \(recordings[index].debugDescription)")
        } else {
            print("Error: Recording with ID \(id) not found")
        }
    }
    
    func updateRecordingTranscription(id: UUID, transcriptionText: String?, originalTranscriptionText: String? = nil) {
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            recordings[index].transcription = transcriptionText
            recordings[index].originalTranscription = originalTranscriptionText
            recordings[index].isTranscribed = transcriptionText != nil && !transcriptionText!.isEmpty
            
            saveRecordingsMetadata()
            print("Updated recording transcription text (Final: \(transcriptionText != nil), Original: \(originalTranscriptionText != nil)) and status for ID \(id)")
            // Post notification after update
            NotificationCenter.default.post(name: .recordingsUpdated, object: nil)
        } else {
            print("Error: Recording with ID \(id) not found for transcription update")
        }
    }
    
    func markAsTranscribed(id: UUID) {
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            recordings[index].isTranscribed = true
            saveRecordingsMetadata()
            print("Marked recording as transcribed: \(recordings[index].debugDescription)")
        } else {
            print("Error: Recording with ID \(id) not found")
        }
    }
    
    func loadRecordings() {
        print("💾 Attempting to load recordings metadata from \(metadataURL.path)")
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            print("💾 Metadata file not found. Initializing empty recordings array.")
            recordings = []
            return
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            // Decoding will now use the custom init(from:) in AudioRecording
            let loadedRecordings = try decoder.decode([AudioRecording].self, from: data)
            self.recordings = loadedRecordings // Update the main array
            
            // Log details after loading
            let transcribedCount = recordings.filter { $0.isTranscribed }.count
            let untranscribedCount = recordings.count - transcribedCount
            let withTextCount = recordings.filter { $0.transcription != nil && !$0.transcription!.isEmpty }.count
            print("✅ Successfully loaded recordings metadata. Total=\(recordings.count), Transcribed=\(transcribedCount), Untranscribed=\(untranscribedCount), WithText=\(withTextCount)")
            
            // Verify loaded types (optional debug step)
            for rec in recordings {
                 print("   Loaded recording ID: \(rec.id), TypeName: '\(rec.recordingTypeName)', Date: \(rec.date)")
            }

        } catch let decodingError as DecodingError {
            print("❌ Error decoding recordings metadata: \(decodingError)")
             // Handle specific decoding errors for more insight
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("    Type mismatch: \(type), Context: \(context.debugDescription)")
            case .valueNotFound(let value, let context):
                print("    Value not found: \(value), Context: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("    Key not found: \(key), Context: \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("    Data corrupted: Context: \(context.debugDescription)")
            @unknown default:
                print("    Unknown decoding error")
            }
            // Decide recovery strategy: Use empty array? Try backup? Alert user?
            recordings = []
            // Maybe don't save immediately if load failed, could overwrite good data
            // saveRecordingsMetadata()

        } catch {
            print("❌ Error loading recordings metadata (other): \(error.localizedDescription)")
            recordings = []
            // saveRecordingsMetadata()
        }
    }
    
    
    func getRecording(by id: UUID) -> AudioRecording? {
            return recordings.first { $0.id == id }
        }
    
    func deleteRecording(id: UUID) {
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            let recordingToDelete = recordings[index]
            recordings.remove(at: index)
            saveRecordingsMetadata()
            print("Deleted recording: \(recordingToDelete.debugDescription)")
            
            // Delete the audio file
            let audioFileURL = documentsDirectory.appendingPathComponent(recordingToDelete.url)
            do {
                try fileManager.removeItem(at: audioFileURL)
                print("Deleted audio file: \(audioFileURL.path)")
            } catch {
                print("Error deleting audio file: \(error.localizedDescription)")
            }
            // Post notification after deletion
            NotificationCenter.default.post(name: .recordingsUpdated, object: nil)
        } else {
            print("Error: Recording with ID \(id) not found for deletion")
        }
    }

    // --- ADDED: Function to get the full file URL ---
    func getAudioFileURL(for filename: String) -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        // Check if the file actually exists before returning the URL
        if fileManager.fileExists(atPath: fileURL.path) {
             print("🔊 Found audio file at: \(fileURL.path)")
            return fileURL
        } else {
            print("⚠️ Audio file NOT found at: \(fileURL.path)")
            return nil // Return nil if the file doesn't exist
        }
    }
    
    // --- ADDED: Function to update recording durations after processing ---
    func updateRecordingDurations(
        recordingId: UUID,
        originalDuration: TimeInterval,
        processedDuration: TimeInterval,
        originalFileSize: Int64,
        processedFileSize: Int64,
        processedURL: URL
    ) -> AudioRecording? {
        guard let index = recordings.firstIndex(where: { $0.id == recordingId }) else {
            print("⚠️ Recording with ID \(recordingId) not found for duration update")
            return nil
        }
        
        // Calculate reduction percentage
        let reductionPercentage = originalDuration > 0 ? 
            Int(100 - (processedDuration / originalDuration * 100)) : 0
        
        // Update the recording to use the processed file
        recordings[index].url = processedURL.lastPathComponent
        recordings[index].originalDuration = originalDuration
        recordings[index].processedDuration = processedDuration
        recordings[index].reductionPercentage = reductionPercentage
        
        // Save updated metadata
        saveRecordingsMetadata()
        print("✅ Updated durations and URL for recording \(recordingId). Original: \(originalDuration)s, Processed: \(processedDuration)s, New URL: \(processedURL.lastPathComponent)")
        return recordings[index]
    }

    private func migrateTranscriptionsIfNeeded() {
        print("Checking for legacy transcriptions_metadata.json for migration...")
        guard fileManager.fileExists(atPath: legacyMetadataURL.path) else {
            print("No legacy transcriptions_metadata.json found. Migration not needed.")
            return
        }
        
        print("Legacy transcriptions_metadata.json found. Starting migration...")
        
        do {
            let data = try Data(contentsOf: legacyMetadataURL)
            let decoder = JSONDecoder()
            let legacyTranscriptions = try decoder.decode([LegacyTranscription].self, from: data)
            
            var migratedCount = 0
            for legacyTranscription in legacyTranscriptions {
                if let index = recordings.firstIndex(where: { $0.id == legacyTranscription.recordingId }) {
                    // Check if this recording already has transcription data from new system
                    if recordings[index].transcription == nil || recordings[index].transcription!.isEmpty {
                        recordings[index].transcription = legacyTranscription.text
                        recordings[index].isTranscribed = !legacyTranscription.text.isEmpty
                        migratedCount += 1
                        print("Migrated legacy transcription for recording ID: \(legacyTranscription.recordingId)")
                    } else {
                        print("Skipping migration for recording ID: \(legacyTranscription.recordingId) - already has transcription.")
                    }
                } else {
                    print("Warning: Legacy transcription found for recording ID: \(legacyTranscription.recordingId), but no matching recording in recordings_metadata.json")
                }
            }
            
            if migratedCount > 0 {
                saveRecordingsMetadata() // Save changes after migration
                print("Successfully migrated \(migratedCount) legacy transcriptions.")
            } else {
                print("No new transcriptions were migrated (existing data might have taken precedence).")
            }
            
            // Optionally, rename or delete the old file after successful migration
            // For safety, let's just log for now.
            print("Consider renaming or deleting the old transcriptions_metadata.json file at: \(legacyMetadataURL.path)")
            
        } catch {
            print("Error during legacy transcription migration: \(error.localizedDescription)")
        }
    }
}

// Define the AudioRecording struct if it's not already defined elsewhere
// Ensure this matches the structure used in VoiceRecorder or adapt as needed
struct AudioRecording: Identifiable, Codable, Hashable {
    var id: UUID
    var url: String // Now just the filename, not full path
    var recordingTypeName: String
    var isTranscribed: Bool
    var date: Date
    var originalDuration: TimeInterval?
    var processedDuration: TimeInterval?
    var reductionPercentage: Int?
    var totalPauseDuration: TimeInterval?
    var question: String?
    var transcription: String?
    var originalTranscription: String? // Store the Whisper output before GPT processing
    
    // Custom initializer if needed for decoding specific date formats or other transformations
    // For example, if date is stored in a non-standard string format
    
    // Computed property for debugging
    var debugDescription: String {
        return "ID: \(id), URL: \(url), Type: \(recordingTypeName), Transcribed: \(isTranscribed), Date: \(date)"
    }
}

// If AudioRecording might have missing fields in older JSON data, 
// you might need a custom Codable implementation or make fields optional.
// Example of handling potentially missing `recordingTypeName` during decoding:
extension AudioRecording {
    enum CodingKeys: String, CodingKey {
        case id, url, recordingTypeName, isTranscribed, date, originalDuration, processedDuration, reductionPercentage, totalPauseDuration, question, transcription, originalTranscription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        
        // Provide a default value for recordingTypeName if it's missing
        recordingTypeName = try container.decodeIfPresent(String.self, forKey: .recordingTypeName) ?? "DefaultType"
        
        isTranscribed = try container.decode(Bool.self, forKey: .isTranscribed)
        date = try container.decode(Date.self, forKey: .date)
        originalDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .originalDuration)
        processedDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .processedDuration)
        reductionPercentage = try container.decodeIfPresent(Int.self, forKey: .reductionPercentage)
        totalPauseDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .totalPauseDuration)
        question = try container.decodeIfPresent(String.self, forKey: .question)
        transcription = try container.decodeIfPresent(String.self, forKey: .transcription)
        originalTranscription = try container.decodeIfPresent(String.self, forKey: .originalTranscription)
    }
} 