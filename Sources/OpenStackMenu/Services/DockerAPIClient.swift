import Foundation
import os

/// Raw JSON structure returned by `docker ps --format '{{json .}}'`
struct DockerContainerJSON: Codable, Sendable {
    let ID: String
    let Names: String
    let Image: String
    let State: String
    let Status: String
    let Ports: String
    let Labels: String?

    enum CodingKeys: String, CodingKey {
        case ID, Names, Image, State, Status, Ports, Labels
    }

    /// Parsed labels dictionary (computed from raw Labels string)
    var parsedLabels: [String: String] {
        guard let labels = Labels else { return [:] }
        
        // Labels come as comma-separated key=value pairs
        // e.g., "com.docker.compose.project=myapp,com.docker.compose.service=web"
        var result: [String: String] = [:]
        let pairs = labels.split(separator: ",")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                result[String(kv[0]).trimmingCharacters(in: .whitespaces)] = String(kv[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }
}

/// Docker REST API client that communicates via SSH transport.
struct DockerAPIClient: Sendable {
    private let sshTransport: SSHTransport
    private let logger = Logger(subsystem: "com.openstackmenu.OpenStackMenu", category: "DockerAPIClient")

    init(sshTransport: SSHTransport = SSHTransport()) {
        self.sshTransport = sshTransport
    }

    /// Lists all containers (running and stopped) on the remote Docker host.
    func listContainers(on server: ServerConnection) async throws -> [DockerContainerJSON] {
        let data = try await sshTransport.executeDockerCommand(
            on: server,
            dockerArgs: ["ps", "-a", "--format", "{{json .}}"]
        )

        guard let output = String(data: data, encoding: .utf8) else {
            throw SSHTransportError.outputNotParseable("Output is not valid UTF-8")
        }

        logger.info("Raw docker ps output (\(output.count) bytes)")

        let lines = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        logger.info("Found \(lines.count) non-empty lines in output")

        // Log first line for debugging
        if let firstLine = lines.first {
            logger.info("First line sample: \(firstLine.prefix(300), privacy: .public)")
        }

        let containers = lines.compactMap { line -> DockerContainerJSON? in
            guard let lineData = line.data(using: .utf8) else { return nil }
            do {
                return try JSONDecoder().decode(DockerContainerJSON.self, from: lineData)
            } catch {
                logger.warning("Failed to parse line: \(line.prefix(200), privacy: .public) — \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        logger.info("Successfully parsed \(containers.count) containers")
        return containers
    }

    /// Converts raw Docker JSON into our domain model.
    func toContainerInfo(
        _ dockerContainers: [DockerContainerJSON],
        server: ServerConnection
    ) -> [ContainerInfo] {
        dockerContainers.map { dc in
            let cleanedName = dc.Names.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            return ContainerInfo(
                id: dc.ID,
                name: cleanedName,
                image: dc.Image,
                state: dc.State,
                status: dc.Status,
                ports: parsePorts(dc.Ports),
                composeProject: dc.parsedLabels["com.docker.compose.project"],
                labels: dc.parsedLabels,
                serverID: server.id,
                serverName: server.name
            )
        }
    }

    // MARK: - Private

    /// Parses Docker's port format string into structured port mappings.
    /// Example input: "0.0.0.0:32400->32400/tcp, 8123/tcp, :::3000->3000/tcp"
    private func parsePorts(_ portsString: String) -> [ContainerInfo.PortMapping] {
        guard !portsString.isEmpty else { return [] }

        return portsString.split(separator: ",").compactMap { entry in
            parsePortEntry(String(entry).trimmingCharacters(in: .whitespaces))
        }
    }

    private func parsePortEntry(_ entry: String) -> ContainerInfo.PortMapping? {
        let parts = entry.components(separatedBy: "->")

        let publicMapping: String
        let privatePart: String

        if parts.count == 2 {
            publicMapping = parts[0]
            privatePart = parts[1]
        } else {
            publicMapping = ""
            privatePart = parts[0]
        }

        let privateComponents = privatePart.split(separator: "/")
        let type = privateComponents.count > 1 ? String(privateComponents[1]) : "tcp"
        let privatePort = Int(privateComponents[0]) ?? 0

        let ip: String?
        let publicPort: Int?

        if !publicMapping.isEmpty {
            // Handle Docker port formats:
            // IPv4: "0.0.0.0:32400" -> ip="0.0.0.0", port=32400
            // IPv6 wildcard: ":::3000" -> ip="::", port=3000
            // IPv6 bracketed: "[::1]:3000" -> ip="::1", port=3000
            // Port only: "32400" -> ip=nil, port=32400

            if publicMapping.hasPrefix("[") {
                // Bracketed IPv6: [::1]:3000
                if let bracketEnd = publicMapping.firstIndex(of: "]") {
                    let afterBracket = publicMapping[publicMapping.index(after: bracketEnd)...]
                    ip = String(publicMapping[publicMapping.index(after: publicMapping.startIndex)..<bracketEnd])
                    if afterBracket.hasPrefix(":") {
                        publicPort = Int(String(afterBracket.dropFirst()))
                    } else {
                        publicPort = nil
                    }
                } else {
                    ip = nil
                    publicPort = nil
                }
            } else if publicMapping.contains(":::") {
                // IPv6 wildcard (:::) — format is :::PORT
                let portStr = String(publicMapping.split(separator: ":").last ?? "")
                ip = "::"
                publicPort = Int(portStr)
            } else {
                // IPv4 or port only
                let publicComponents = publicMapping.split(separator: ":")
                if publicComponents.count == 2 {
                    ip = String(publicComponents[0])
                    publicPort = Int(publicComponents[1])
                } else {
                    ip = nil
                    publicPort = Int(publicComponents[0])
                }
            }
        } else {
            ip = nil
            publicPort = nil
        }

        return ContainerInfo.PortMapping(
            ip: ip,
            privatePort: privatePort,
            publicPort: publicPort,
            type: type
        )
    }
}
