import Foundation
import os

/// Manages reading and writing the app configuration as JSON.
/// Uses `@unchecked Sendable` because FileManager is not Sendable,
/// but all calls to this class happen from `@MainActor` contexts,
/// so there is no concurrent access in practice.
final class ConfigurationManager: @unchecked Sendable {
    static let shared = ConfigurationManager()

    private let logger = Logger(subsystem: "com.openstackmenu.OpenStackMenu", category: "ConfigurationManager")

    private init() {}

    var configDirectory: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        return appSupport.appendingPathComponent("OpenStackMenu", isDirectory: true)
    }

    var configFileURL: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    /// Loads the configuration from disk. Returns default config if the file doesn't exist.
    func loadConfig() -> AppConfig {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            logger.info("No config file found, returning default config.")
            let defaultConfig = AppConfig.defaultConfig
            try? saveConfig(defaultConfig)
            return defaultConfig
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription). Returning default config.")
            return AppConfig.defaultConfig
        }
    }

    /// Saves configuration to disk as pretty-printed JSON.
    func saveConfig(_ config: AppConfig) throws {
        if !FileManager.default.fileExists(atPath: configDirectory.path) {
            try FileManager.default.createDirectory(
                at: configDirectory,
                withIntermediateDirectories: true
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configFileURL, options: .atomic)
        logger.info("Config saved to \(self.configFileURL.path)")
    }
}
