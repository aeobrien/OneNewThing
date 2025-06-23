// TranscriptionService.swift

import Foundation
import AVFoundation
import UniformTypeIdentifiers

// Define a tuple to hold both transcriptions
typealias TranscriptionResultTuple = (original: String?, final: String)

// The TranscriptionService handles communication with transcription APIs
// It converts audio to text and can process the text further with GPT
class TranscriptionService {
    typealias StatusUpdateHandler = ((String) -> Void)
    
    // Static default prompt for GPT processing - this can be overridden
    private static let defaultGPTPrompt = "You are a helpful assistant processing a voice recording. Organize the transcribed content into clear, well-formatted text. Fix any obvious transcription errors, improve readability, and maintain the original meaning. Do not add any new information that wasn't in the original content."
    
    // MARK: - API Configuration
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
    }
    private let transcriptionEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let chatCompletionEndpoint = "https://api.openai.com/v1/chat/completions"
    
    // MARK: - Transcription
    
    enum TranscriptionError: Error {
        case invalidEndpoint
        case invalidResponse
        case apiError(message: String)
        case serverError(statusCode: Int)
        case noData
        case parsingFailed
        case fileError(reason: String)
    }
    
    func transcribeAudio(
        fileURL: URL,
        requiresSecondAPICall: Bool = false, // Determines if GPT processing is needed
        promptForSecondCall: String = TranscriptionService.defaultGPTPrompt, // Prompt for GPT if used
        statusUpdate: StatusUpdateHandler? = nil,
        completion: @escaping (Result<TranscriptionResultTuple, Error>) -> Void
    ) {
        // Validate audio file size and existence before proceeding
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("Error: Audio file does not exist at path: \(fileURL.path)")
                statusUpdate?("Error: Audio file not found.")
                completion(.failure(TranscriptionError.fileError(reason: "Audio file not found at specified path.")))
                return
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSize) / (1024 * 1024)
            print("AudioProcessor - TranscribeAudio - File size: \(String(format: "%.2f", fileSizeMB)) MB for file \(fileURL.lastPathComponent)")
            
            if fileSize == 0 {
                 print("Warning: Audio file size is 0 bytes. Path: \(fileURL.path)")
                 statusUpdate?("Warning: Audio file is empty.")
                 // Depending on strictness, you might want to fail here
                 // completion(.failure(TranscriptionError.fileError(reason: "Audio file is empty.")))
                 // return
            }

            // OpenAI Whisper API has a 25MB file limit
            if fileSizeMB > 25 {
                print("Error: File size (\(String(format: "%.1f", fileSizeMB))MB) exceeds OpenAI's 25MB limit. Transcription will likely fail.")
                statusUpdate?("Error: File too large (\(String(format: "%.1f", fileSizeMB))MB). Max 25MB.")
                completion(.failure(TranscriptionError.fileError(reason: "File size exceeds 25MB limit.")))
                return
            }
        } catch {
            print("Error checking file size or existence: \(error.localizedDescription). Path: \(fileURL.path)")
            statusUpdate?("Error accessing audio file details.")
            completion(.failure(TranscriptionError.fileError(reason: "Could not access file attributes: \(error.localizedDescription)")))
            return
        }
        
        // Check if API key is configured
        guard !apiKey.isEmpty else {
            statusUpdate?("API key not configured. Please add your OpenAI API key in Settings.")
            completion(.failure(TranscriptionError.apiError(message: "API key not configured")))
            return
        }
        
        guard let endpointURL = URL(string: transcriptionEndpoint) else {
            statusUpdate?("Internal error: Invalid API endpoint.")
            completion(.failure(TranscriptionError.invalidEndpoint))
            return
        }

        let fileNameForStatus = fileURL.lastPathComponent
        statusUpdate?(requiresSecondAPICall ?
            "Step 1/2: Preparing \"\(fileNameForStatus)\" for transcription..." :
            "Preparing \"\(fileNameForStatus)\" for transcription...")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes timeout for potentially large files
        
        do {
            request.httpBody = try createMultipartBody(
                fileURL: fileURL,
                model: "whisper-1", // Using the base Whisper model
                prompt: "", // Initial prompt for Whisper if any (can be empty)
                boundary: boundary
            )
            statusUpdate?(requiresSecondAPICall ?
                "Step 1/2: Sending audio to OpenAI..." :
                "Sending audio to OpenAI...")
        } catch let error as TranscriptionError {
            statusUpdate?("Error creating request: \(error.localizedDescription)")
            completion(.failure(error))
            return
        } catch {
            statusUpdate?("Unexpected error creating request: \(error.localizedDescription)")
            completion(.failure(TranscriptionError.fileError(reason: "Failed to prepare request body: \(error.localizedDescription)")))
            return
        }
        
        print("TranscriptionService: Sending transcription request to OpenAI for \(fileURL.lastPathComponent)")
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("TranscriptionService: Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    statusUpdate?("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("TranscriptionService: Invalid response received.")
                DispatchQueue.main.async {
                    statusUpdate?("Invalid response from server.")
                    completion(.failure(TranscriptionError.invalidResponse))
                }
                return
            }
            
            print("TranscriptionService: HTTP Status Code from OpenAI: \(httpResponse.statusCode)")
            DispatchQueue.main.async {
                statusUpdate?(requiresSecondAPICall ?
                    "Step 1/2: Received response (Status: \(httpResponse.statusCode))" :
                    "Received response (Status: \(httpResponse.statusCode))")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage = "Server error: \(httpResponse.statusCode)"
                if let data = data, let apiErrorMsg = String(data: data, encoding: .utf8) {
                    errorMessage = "API Error (\(httpResponse.statusCode)): \(apiErrorMsg)"
                    print("TranscriptionService: API Error Response: \(apiErrorMsg)")
                }
                DispatchQueue.main.async {
                    statusUpdate?(errorMessage)
                    completion(.failure(TranscriptionError.apiError(message: errorMessage)))
                }
                return
            }
            
            guard let data = data else {
                print("TranscriptionService: No data received from server.")
                DispatchQueue.main.async {
                    statusUpdate?("No data received from server.")
                    completion(.failure(TranscriptionError.noData))
                }
                return
            }
            
            do {
                DispatchQueue.main.async {
                    statusUpdate?(requiresSecondAPICall ?
                        "Step 1/2: Processing initial transcription..." :
                        "Processing transcription...")
                }
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let initialTranscription = json["text"] as? String {
                    print("TranscriptionService: Initial transcription received: \(initialTranscription.prefix(100))...")
                    
                    if requiresSecondAPICall {
                        DispatchQueue.main.async {
                            statusUpdate?("Step 1/2 Complete. Preparing for refinement...")
                             // Small delay for UI update if necessary
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.processTranscriptionWithGPT(
                                    initialTranscription: initialTranscription,
                                    prompt: promptForSecondCall,
                                    statusUpdate: statusUpdate,
                                    completion: completion
                                )
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            statusUpdate?("Transcription complete!")
                            completion(.success((original: nil, final: initialTranscription)))
                        }
                    }
                } else {
                    print("TranscriptionService: Failed to parse transcription response JSON.")
                    DispatchQueue.main.async {
                        statusUpdate?("Failed to parse transcription data.")
                        completion(.failure(TranscriptionError.parsingFailed))
                    }
                }
            } catch {
                print("TranscriptionService: Error parsing JSON response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    statusUpdate?("Error processing response data.")
                    completion(.failure(error))
                }
            }
        }
        task.resume()
    }
    
    // MARK: - GPT Processing (Second API Call)
    private func processTranscriptionWithGPT(
        initialTranscription: String,
        prompt: String,
        statusUpdate: StatusUpdateHandler? = nil,
        completion: @escaping (Result<TranscriptionResultTuple, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            statusUpdate?("Step 2/2: Processing with advanced model...")
        }
        print("TranscriptionService: Starting GPT processing for transcription.")
        
        // Check if API key is configured
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                statusUpdate?("API key not configured. Please add your OpenAI API key in Settings.")
            }
            completion(.failure(TranscriptionError.apiError(message: "API key not configured")))
            return
        }
        
        guard let url = URL(string: chatCompletionEndpoint) else {
            DispatchQueue.main.async {
                statusUpdate?("Internal error: Invalid GPT endpoint.")
            }
            completion(.failure(TranscriptionError.invalidEndpoint))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // 3 minutes timeout for GPT processing
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini", // Specify a suitable model, e.g., gpt-3.5-turbo or gpt-4
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": initialTranscription]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("TranscriptionService: Error creating GPT request JSON: \(error.localizedDescription)")
            DispatchQueue.main.async {
                statusUpdate?("Error preparing GPT request.")
            }
            completion(.failure(error))
            return
        }
        
        DispatchQueue.main.async {
            statusUpdate?("Step 2/2: Sending to advanced model...")
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("TranscriptionService: GPT Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    statusUpdate?("Network error during GPT processing.")
                }
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("TranscriptionService: Invalid GPT response.")
                DispatchQueue.main.async {
                    statusUpdate?("Invalid response from GPT service.")
                }
                completion(.failure(TranscriptionError.invalidResponse))
                return
            }
            
            print("TranscriptionService: GPT HTTP Status Code: \(httpResponse.statusCode)")
            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("TranscriptionService: GPT Raw Response Body: \(responseBody.prefix(500))...")
            }

            DispatchQueue.main.async {
                statusUpdate?("Step 2/2: Received GPT response (Status: \(httpResponse.statusCode))")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage = "GPT Server error: \(httpResponse.statusCode)"
                if let data = data, let apiErrorMsg = String(data: data, encoding: .utf8) {
                    errorMessage = "GPT API Error (\(httpResponse.statusCode)): \(apiErrorMsg)"
                    print("TranscriptionService: GPT API Error: \(apiErrorMsg)")
                }
                 DispatchQueue.main.async {
                    statusUpdate?(errorMessage)
                }
                completion(.failure(TranscriptionError.apiError(message: errorMessage)))
                return
            }
            
            guard let data = data else {
                print("TranscriptionService: No data from GPT.")
                 DispatchQueue.main.async {
                    statusUpdate?("No data received from GPT service.")
                }
                completion(.failure(TranscriptionError.noData))
                return
            }
            
            do {
                DispatchQueue.main.async {
                    statusUpdate?("Step 2/2: Processing refined transcription...")
                }
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let refinedText = message["content"] as? String {
                    print("TranscriptionService: Refined transcription received: \(refinedText.prefix(100))...")
                    DispatchQueue.main.async {
                        statusUpdate?("Transcription refinement complete!")
                        completion(.success((original: initialTranscription, final: refinedText)))
                    }
                } else {
                    print("TranscriptionService: Failed to parse refined transcription JSON.")
                    DispatchQueue.main.async {
                        statusUpdate?("Failed to parse refined data.")
                    }
                    completion(.failure(TranscriptionError.parsingFailed))
                }
            } catch {
                print("TranscriptionService: Error parsing GPT JSON response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    statusUpdate?("Error processing refined data.")
                }
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    // MARK: - Multipart Body Creation
    private func createMultipartBody(
        fileURL: URL,
        model: String,
        prompt: String,
        boundary: String
    ) throws -> Data {
        var body = Data()
        
        let filename = fileURL.lastPathComponent
        var mimeType = "audio/m4a" // Default MimeType
        if let utType = UTType(filenameExtension: fileURL.pathExtension) {
            if let preferredMimeType = utType.preferredMIMEType {
                mimeType = preferredMimeType
            } else {
                 print("Warning: Could not determine preferred MIME type for \(fileURL.pathExtension). Using default \(mimeType).")
            }
        } else {
            print("Warning: Could not determine UTType for \(fileURL.pathExtension). Using default \(mimeType).")
        }
        print("Using MIME type: \(mimeType) for file: \(filename)")

        // Append model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Append prompt parameter if not empty
        if !prompt.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }
        
        // Append file data
        do {
            let audioData = try Data(contentsOf: fileURL)
            if audioData.isEmpty {
                print("Error: Audio file data is empty for \(filename). File path: \(fileURL.path)")
                throw TranscriptionError.fileError(reason: "Audio file is empty.")
            }
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        } catch {
            print("Error reading audio file data for multipart body: \(error.localizedDescription). Path: \(fileURL.path)")
            throw TranscriptionError.fileError(reason: "Failed to read audio file: \(error.localizedDescription)")
        }
        
        // Append closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
} 
