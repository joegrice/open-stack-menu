import SwiftUI

enum ContainerStatus: String, Sendable, Equatable {
    case online
    case offline
    case degraded
    case unknown
    case checking

    var displayName: String {
        switch self {
        case .online:   return "Online"
        case .offline:  return "Offline"
        case .degraded: return "Degraded"
        case .unknown:  return "Unknown"
        case .checking: return "Checking..."
        }
    }

    var color: Color {
        switch self {
        case .online:   return .green
        case .offline:  return .red
        case .degraded: return .orange
        case .unknown:  return .gray
        case .checking: return .blue
        }
    }
}

struct HealthCheckResult: Sendable {
    var containerID: String
    var isHealthy: Bool
    var statusCode: Int?
    var responseTime: TimeInterval
    var errorMessage: String?
}
