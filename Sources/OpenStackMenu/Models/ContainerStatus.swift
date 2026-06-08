import SwiftUI

enum ContainerStatus: String, Sendable, Equatable {
    case online
    case offline
    case degraded
    case restarting
    case unknown
    case checking

    var displayName: String {
        switch self {
        case .online:     return "Online"
        case .offline:    return "Offline"
        case .degraded:   return "Degraded"
        case .restarting: return "Restarting"
        case .unknown:    return "Unknown"
        case .checking:   return "Checking..."
        }
    }

    var color: Color {
        switch self {
        case .online:     return .green
        case .offline:    return .red
        case .degraded:   return .orange
        case .restarting: return .orange
        case .unknown:    return .gray
        case .checking:   return .blue
        }
    }

    var symbolName: String {
        switch self {
        case .online:     return "circle.fill"
        case .offline:    return "circle.fill"
        case .degraded:   return "circle.fill"
        case .restarting: return "arrow.clockwise"
        case .unknown:    return "circle"
        case .checking:   return "circle.fill"
        }
    }

    var symbolColor: Color {
        switch self {
        case .online:     return .green
        case .offline:    return .red
        case .degraded:   return .orange
        case .restarting: return .orange
        case .unknown:    return .gray
        case .checking:   return .blue
        }
    }

    var emoji: String {
        switch self {
        case .online:     return "🟢"
        case .offline:    return "🔴"
        case .degraded:   return "🟠"
        case .restarting: return "🟠"
        case .unknown:    return "⚪"
        case .checking:   return "🔵"
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
