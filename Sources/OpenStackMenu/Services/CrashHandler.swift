import Foundation
import os

/// Handles uncaught exceptions and signals to prevent silent crashes
/// and provide better diagnostics.
enum CrashHandler {
    private static let logger = Logger(subsystem: "com.openstackmenu.OpenStackMenu", category: "CrashHandler")

    /// Install uncaught exception handler and signal handlers.
    /// Call this early in app startup (before SwiftUI app initialization).
    static func install() {
        installUncaughtExceptionHandler()
        installSignalHandlers()
        logger.info("Crash handlers installed")
    }

    // MARK: - Uncaught Exception Handler

    private static func installUncaughtExceptionHandler() {
        let handler: @convention(c) (NSException) -> Void = { exception in
            let name = exception.name.rawValue
            let reason = exception.reason ?? "unknown"

            // Use low-level logging since we're in exception context
            let logMessage = "Uncaught exception: \(name) - \(reason)\n"
            let fd = STDERR_FILENO
            _ = write(fd, logMessage, logMessage.utf8.count)

            // Exit with non-zero code to trigger LaunchAgent relaunch
            exit(1)
        }
        NSSetUncaughtExceptionHandler(handler)
    }

    // MARK: - Signal Handlers

    private static func installSignalHandlers() {
        // Handle common crash signals
        let signalsToHandle: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL]

        let handler: @convention(c) (Int32) -> Void = { sig in
            // Can't use Logger here safely in signal context, use low-level write
            let message = "Caught signal \(sig)\n"
            let fd = STDERR_FILENO
            _ = write(fd, message, message.utf8.count)

            // Exit with error code to trigger LaunchAgent relaunch
            _exit(1)
        }

        for sigNum in signalsToHandle {
            signal(sigNum, handler)
        }
    }
}
