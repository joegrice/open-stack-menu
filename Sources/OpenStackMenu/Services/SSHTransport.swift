import Foundation
import os

/// Error type for SSH transport failures.
enum SSHTransportError: Error, LocalizedError {
    case commandFailed(exitCode: Int32, message: String)
    case outputNotParseable(String)
    case passwordNotSet

    var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let msg):
            return "SSH command failed (exit \(code)): \(msg)"
        case .outputNotParseable(let details):
            return "Could not parse command output: \(details)"
        case .passwordNotSet:
            return "Password authentication enabled but no password stored in Keychain"
        }
    }
}

/// Executes Docker commands on a remote server via the system `ssh` command.
/// Supports both key-based auth (ssh-agent/1Password) and password auth (SSH_ASKPASS + Keychain).
struct SSHTransport: Sendable {

    private let logger = Logger(subsystem: "com.openstackmenu.OpenStackMenu", category: "SSHTransport")

    /// Builds and executes an SSH command to run Docker on the remote server.
    /// Returns the raw stdout data from the command.
    func executeDockerCommand(on server: ServerConnection, dockerArgs: [String]) async throws -> Data {
        let command = buildSSHCommand(server: server, dockerArgs: dockerArgs)
        logger.info("SSH command: \(command.joined(separator: " "))")
        return try await executeCommand(command, server: server)
    }

    // MARK: - Private

    private func buildSSHCommand(server: ServerConnection, dockerArgs: [String]) -> [String] {
        var args = ["ssh"]

        // Connection multiplexing for performance
        args.append(contentsOf: ["-o", "ControlMaster=auto"])
        args.append(contentsOf: ["-o", "ControlPath=~/.ssh/opm-%r@%h:%p"])
        args.append(contentsOf: ["-o", "ControlPersist=60s"])
        args.append(contentsOf: ["-o", "ConnectTimeout=10"])
        args.append(contentsOf: ["-o", "StrictHostKeyChecking=accept-new"])

        // When using password auth, disable pubkey to avoid "Permission denied" from rejected keys
        if server.usePassword {
            args.append(contentsOf: ["-o", "PubkeyAuthentication=no"])
            args.append(contentsOf: ["-o", "PreferredAuthentications=password"])
        }

        // Custom identity file
        if let identityFile = server.identityFile, !identityFile.isEmpty {
            args.append(contentsOf: ["-i", identityFile])
        }

        // Non-default SSH port
        if server.port != 22 {
            args.append(contentsOf: ["-p", String(server.port)])
        }

        // Destination
        args.append(server.sshDestination)

        // Docker command - properly quoted for remote shell execution
        // ssh concatenates all args after destination into a single command string
        // so we need to ensure special characters are properly escaped
        let dockerCommand = buildDockerCommand(dockerArgs)
        args.append(dockerCommand)

        return args
    }

    /// Builds a properly quoted docker command string for remote execution.
    /// Ensures arguments with spaces/special chars (like --format '{{json .}}') are quoted.
    private func buildDockerCommand(_ dockerArgs: [String]) -> String {
        var parts = ["docker"]
        for arg in dockerArgs {
            if arg.contains(" ") || arg.contains("{") || arg.contains("}") || arg.contains("'") || arg.contains("\"") {
                // Quote arguments with special characters
                let escaped = arg.replacingOccurrences(of: "'", with: "'\\''")
                parts.append("'\(escaped)'")
            } else {
                parts.append(arg)
            }
        }
        return parts.joined(separator: " ")
    }

    private func executeCommand(_ command: [String], server: ServerConnection) async throws -> Data {
        actor ProcessState {
            var hasResumed = false
            func tryResume() -> Bool {
                guard !hasResumed else { return false }
                hasResumed = true
                return true
            }
        }

        let state = ProcessState()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = command

            // Set up environment
            var env = ProcessInfo.processInfo.environment

            // 1Password SSH agent support
            if !server.usePassword, let agentSocket = findSSHAuthSocket() {
                env["SSH_AUTH_SOCK"] = agentSocket
                logger.info("Using SSH agent socket: \(agentSocket)")
            }

            // Password authentication via SSH_ASKPASS
            if server.usePassword {
                guard KeychainHelper.passwordExists(for: server.id) else {
                    continuation.resume(throwing: SSHTransportError.passwordNotSet)
                    return
                }

                if let askpassPath = findAskpassScript() {
                    env["SSH_ASKPASS"] = askpassPath
                    env["SSH_OPM_SERVER_ID"] = server.id.uuidString
                    env["SSH_ASKPASS_REQUIRE"] = "force"
                    // DISPLAY is required for SSH_ASKPASS to work (even though we don't use X11)
                    env["DISPLAY"] = ":0"
                    logger.info("Using SSH_ASKPASS for password auth")
                } else {
                    logger.error("askpass.sh script not found in app bundle")
                    continuation.resume(throwing: SSHTransportError.commandFailed(
                        exitCode: 1,
                        message: "Password auth requires askpass.sh in app Resources"
                    ))
                    return
                }
            }

            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                Task {
                    guard await state.tryResume() else { return }
                    proc.terminate()

                    let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? ""

                    if proc.terminationStatus == 0 {
                        continuation.resume(returning: outputData)
                    } else {
                        let message = errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.logger.error("SSH failed: \(message)")
                        let error = SSHTransportError.commandFailed(
                            exitCode: proc.terminationStatus,
                            message: message
                        )
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Timeout handler: kill the process if it runs too long
            let timeoutSeconds: UInt64 = 30
            Task {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                guard await state.tryResume() else { return }
                process.terminate()
                let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Process timed out after \(timeoutSeconds)s"
                self.logger.error("SSH command timed out after \(timeoutSeconds)s: \(errorMessage)")
                continuation.resume(throwing: SSHTransportError.commandFailed(
                    exitCode: -1,
                    message: "SSH command timed out after \(timeoutSeconds)s"
                ))
            }

            do {
                try process.run()
            } catch {
                Task {
                    guard await state.tryResume() else { return }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Locates the askpass.sh script in the app bundle.
    private func findAskpassScript() -> String? {
        // Check app bundle Resources
        let bundlePath = Bundle.main.resourcePath ?? ""
        let askpassInBundle = "\(bundlePath)/askpass.sh"
        if FileManager.default.fileExists(atPath: askpassInBundle) {
            return askpassInBundle
        }

        // Fallback: check current working directory (for development)
        let cwdAskpass = "Resources/askpass.sh"
        if FileManager.default.fileExists(atPath: cwdAskpass) {
            return cwdAskpass
        }

        return nil
    }

    /// Locates the SSH agent socket. Checks environment, then known 1Password paths.
    private func findSSHAuthSocket() -> String? {
        // 1. Check current environment (works if launched from Terminal)
        if let sock = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"],
           !sock.isEmpty,
           FileManager.default.fileExists(atPath: sock) {
            return sock
        }

        // 2. Check known 1Password SSH agent socket paths
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock",
            "\(home)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock.1",
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // 3. Try to find via glob (in case the group container ID differs)
        let groupContainers = "\(home)/Library/Group Containers"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: groupContainers) {
            for container in contents where container.contains("com.1password") {
                let sockPath = "\(groupContainers)/\(container)/t/agent.sock"
                if FileManager.default.fileExists(atPath: sockPath) {
                    return sockPath
                }
            }
        }

        return nil
    }
}
