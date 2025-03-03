import Foundation

/// The purpose of this class is to encapsulate NSURLSession's interaction code, required to upload
/// a note to Simperium's REST endpoint.
///
class Uploader: NSObject {

    /// Simperium's Token
    ///
    private let token: String

    /// Designated Initializer
    ///
    init(simperiumToken: String) {
        token = simperiumToken
    }

    // MARK: - Public Methods
    func send(_ note: Note) {
        let request = requestToSend(note)

        // Task!
        let sc = URLSessionConfiguration.backgroundSessionConfigurationWithRandomizedIdentifier()

        let session = Foundation.URLSession(configuration: sc, delegate: self, delegateQueue: .main)
        let task = session.downloadTask(with: request)
        task.resume()
    }

    func send(_ note: Note) async throws -> (URL, URLResponse) {
        let request = requestToSend(note)

        let session = Foundation.URLSession(configuration: .default)
        return try await session.download(for: request)
    }

    private func requestToSend(_ note: Note) -> URLRequest {
        // Build the targetURL
        let endpoint = String(format: "%@/%@/%@/i/%@", kSimperiumBaseURL, SPCredentials.simperiumAppID, Settings.bucketName, note.simperiumKey)
        let targetURL = URL(string: endpoint.lowercased())!

        // Request
        var request = URLRequest(url: targetURL)
        request.httpMethod = Settings.httpMethodPost
        request.httpBody = note.toJsonData()
        request.setValue(token, forHTTPHeaderField: Settings.authHeader)

        return request
    }
}

// MARK: - URLSessionDelegate
//
extension Uploader: URLSessionDelegate {

    @objc
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("<> Uploader.didBecomeInvalidWithError: \(String(describing: error))")
    }

    @objc
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("<> Uploader.URLSessionDidFinishEventsForBackgroundURLSession")
    }
}

// MARK: - URLSessionTaskDelegate
//
extension Uploader: URLSessionTaskDelegate {

    @objc
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("<> Uploader.didCompleteWithError: \(String(describing: error))")
    }
}

// MARK: - Settings
//
private struct Settings {
    static let authHeader  = "X-Simperium-Token"
    static let bucketName  = "note"
    static let httpMethodPost  = "POST"
}
