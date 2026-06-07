import Foundation

/// Performs optional HTTP health checks against container URLs.
struct HealthChecker: Sendable {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.httpShouldUsePipelining = false
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    /// Checks a URL endpoint and returns a health result.
    func check(
        url: URL,
        timeout: TimeInterval,
        additionalPath: String?
    ) async -> HealthCheckResult {
        var requestURL = url
        if let path = additionalPath, !path.isEmpty {
            requestURL = url.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let startTime = Date()

        do {
            let (_, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                return HealthCheckResult(
                    containerID: "",
                    isHealthy: false,
                    statusCode: nil,
                    responseTime: elapsed,
                    errorMessage: "Invalid response type"
                )
            }

            let isHealthy = (200..<400).contains(httpResponse.statusCode)
            return HealthCheckResult(
                containerID: "",
                isHealthy: isHealthy,
                statusCode: httpResponse.statusCode,
                responseTime: elapsed,
                errorMessage: isHealthy ? nil : "HTTP \(httpResponse.statusCode)"
            )
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            let message: String

            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    message = "Timed out"
                case .cannotConnectToHost:
                    message = "Host unreachable"
                case .cannotFindHost:
                    message = "DNS resolution failed"
                case .notConnectedToInternet:
                    message = "No network connection"
                default:
                    message = urlError.localizedDescription
                }
            } else {
                message = error.localizedDescription
            }

            return HealthCheckResult(
                containerID: "",
                isHealthy: false,
                statusCode: nil,
                responseTime: elapsed,
                errorMessage: message
            )
        }
    }
}
