import AntiAITunesCore
import Foundation

/// Sends HTTP requests with URLSession.
@MainActor
struct URLSessionHTTPClient: HTTPClient {
    func get(_ url: URL, etag: String?, maxBytes: Int) async throws -> HTTPResponse {
        // Without this, URLCache can answer with a cached 200 instead of passing the 304 through.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let http = response as? HTTPURLResponse
        let body = try await HTTPBody.collect(bytes, limit: maxBytes)
        return HTTPResponse(status: http?.statusCode, etag: http?.value(forHTTPHeaderField: "ETag"), body: body)
    }
}

/// Real time.
@MainActor
struct SystemClock: AntiAITunesCore.Clock {
    var now: Date { Date() }

    func sleep(seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
