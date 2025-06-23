import Foundation
import Network
import SwiftUI // For Color, if used directly, or map to app-specific theme colors

enum NetworkQuality: CustomStringConvertible {
    case unknown
    case poor
    case fair
    case good
    case excellent
    
    var isUsableForTranscription: Bool {
        switch self {
        case .unknown, .poor: // Consider if .fair should also be false for large uploads
            return false
        case .fair, .good, .excellent:
            return true
        }
    }
    
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
    
    // Color representation can be adapted to OneNewThing's UI theme if needed
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .poor: return .red
        case .fair: return .orange
        case .good: return .blue // Or a more theme-appropriate color
        case .excellent: return .green
        }
    }
}

class NetworkReachabilityMonitor: ObservableObject {
    static let shared = NetworkReachabilityMonitor()
    
    @Published var isConnected: Bool = false
    @Published var networkQuality: NetworkQuality = .unknown
    @Published var isTestingQuality: Bool = false
    @Published var lastQualityTestTime: Date?
    @Published var connectionTypeDescription: String = "Initializing..."
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.onenewthing.NetworkMonitor", qos: .background)
    
    // How often to re-test quality even if it was good (e.g., 5 minutes)
    private let qualityTestInterval: TimeInterval = 5 * 60 
    // URL for testing network quality - small, fast, reliable.
    private let qualityTestURL = URL(string: "https://www.apple.com/library/test/success.html")! // Or another reliable host

    private init() {
        monitor = NWPathMonitor()
        print("NetworkMonitor: Initializing.")
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
        print("NetworkMonitor: Deinitialized.")
    }
    
    func startMonitoring() {
        print("NetworkMonitor: Starting path monitor.")
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let newIsConnected = path.status == .satisfied
            let newConnectionType = self.determineConnectionType(path)
            
            DispatchQueue.main.async {
                let oldIsConnected = self.isConnected
                self.isConnected = newIsConnected
                self.connectionTypeDescription = newConnectionType
                
                print("NetworkMonitor: Path update. Connected: \(self.isConnected), Type: \(self.connectionTypeDescription)")

                if oldIsConnected != newIsConnected {
                    NotificationCenter.default.post(name: .networkStatusChanged, object: nil, userInfo: ["isConnected": self.isConnected])
                    if newIsConnected {
                        print("NetworkMonitor: Connection established. Resetting quality and performing initial test.")
                        self.networkQuality = .unknown // Reset quality on new connection
                        self.lastQualityTestTime = nil
                        self.testNetworkQualityIfNeeded() // Test immediately
                    } else {
                        print("NetworkMonitor: Connection lost. Setting quality to poor.")
                        self.networkQuality = .poor // Assume poor quality when disconnected
                        NotificationCenter.default.post(name: .networkQualityChanged, object: nil, userInfo: ["quality": NetworkQuality.poor.description])
                    }
                } else if newIsConnected {
                    // Connection type might have changed (e.g., WiFi to Cellular)
                    // Re-test quality if significant change or if it was unknown
                    self.testNetworkQualityIfNeeded()
                }
            }
        }
        monitor.start(queue: queue)
        // Perform an initial quality test shortly after start if connected
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.isConnected {
                self.testNetworkQuality(forceTest: true) { _ in }
            }
        }
    }
    
    func stopMonitoring() {
        print("NetworkMonitor: Stopping path monitor.")
        monitor.cancel()
    }
    
    private func determineConnectionType(_ path: NWPath) -> String {
        var types: [String] = []
        if path.usesInterfaceType(.wifi) { types.append("WiFi") }
        if path.usesInterfaceType(.cellular) { types.append("Cellular") }
        if path.usesInterfaceType(.wiredEthernet) { types.append("Wired Ethernet") }
        if path.usesInterfaceType(.loopback) { types.append("Loopback") }
        return types.isEmpty ? (path.status == .satisfied ? "Connected (Unknown)" : "Disconnected") : types.joined(separator: " / ")
    }
    
    // Public method to allow other parts of the app to request a quality check
    func checkNetworkForTranscription(completion: @escaping (_ canProceed: Bool, _ message: String) -> Void) {
        guard isConnected else {
            completion(false, "No internet connection.")
            return
        }
        
        testNetworkQuality(forceTest: false) { [weak self] quality in
            guard let self = self else { return }
            if quality.isUsableForTranscription {
                completion(true, "Network quality: \(quality.description)")
            } else {
                completion(false, "Network quality is too poor for transcription (\(quality.description)). Please check your connection.")
            }
        }
    }

    private func testNetworkQualityIfNeeded() {
        // Test if not recently tested or if quality is unknown/poor
        let shouldTest: Bool
        if let lastTest = lastQualityTestTime {
            shouldTest = Date().timeIntervalSince(lastTest) > qualityTestInterval || networkQuality == .unknown || networkQuality == .poor
        } else {
            shouldTest = true // No previous test
        }

        if isConnected && shouldTest {
            testNetworkQuality(forceTest: false) { _ in
                // Result handled by the testNetworkQuality method itself (updates @Published vars)
            }
        }
    }
    
    // Core network quality test function
    private func testNetworkQuality(forceTest: Bool, completion: @escaping (NetworkQuality) -> Void) {
        guard isConnected else {
            print("NetworkMonitor: QualityTest - Not connected, skipping.")
            self.networkQuality = .poor
            completion(.poor)
            return
        }

        if !forceTest, let lastTest = lastQualityTestTime, Date().timeIntervalSince(lastTest) < qualityTestInterval, networkQuality != .unknown, networkQuality != .poor {
            print("NetworkMonitor: QualityTest - Recently tested with good results (\(networkQuality.description)), skipping forced test.")
            completion(networkQuality)
            return
        }
        
        // Prevent multiple simultaneous tests
        guard !isTestingQuality else {
            print("NetworkMonitor: QualityTest - Already in progress.")
            // Potentially return current/last known quality or wait
            completion(networkQuality) // Return current as a fallback
            return
        }
        
        DispatchQueue.main.async {
            self.isTestingQuality = true
        }
        print("NetworkMonitor: QualityTest - Starting test to \(qualityTestURL).")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var request = URLRequest(url: qualityTestURL)
        request.timeoutInterval = 5 // Short timeout for a quick quality check
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000 // milliseconds

            var newQuality: NetworkQuality = .poor

            if let error = error {
                print("NetworkMonitor: QualityTest - Error: \(error.localizedDescription). Latency: \(latency)ms")
                newQuality = .poor
            } else if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode), data != nil {
                print("NetworkMonitor: QualityTest - Success. Latency: \(String(format: "%.2f", latency))ms. Status: \(httpResponse.statusCode).")
                if latency < 150 { newQuality = .excellent }
                else if latency < 400 { newQuality = .good }
                else if latency < 1000 { newQuality = .fair }
                else { newQuality = .poor }
            } else {
                print("NetworkMonitor: QualityTest - Failed (Non-HTTP success or no data). Latency: \(latency)ms. Response: \(String(describing: response))")
                newQuality = .poor
            }
            
            DispatchQueue.main.async {
                self.isTestingQuality = false
                self.lastQualityTestTime = Date()
                if self.networkQuality != newQuality {
                    print("NetworkMonitor: QualityTest - Quality changed from \(self.networkQuality.description) to \(newQuality.description).")
                    self.networkQuality = newQuality
                    NotificationCenter.default.post(name: .networkQualityChanged, object: nil, userInfo: ["quality": newQuality.description])
                } else {
                    print("NetworkMonitor: QualityTest - Quality remains \(newQuality.description).")
                }
                completion(newQuality)
            }
        }.resume()
    }
}

// Ensure Notification.Name extensions are available if not already defined globally
// If Extensions.swift is copied, this might be redundant, but good for standalone use.
// extension Notification.Name {
//     static let networkStatusChanged = Notification.Name("networkStatusChanged")
//     static let networkQualityChanged = Notification.Name("networkQualityChanged")
// } 