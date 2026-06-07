import SwiftUI

/// Manage server connections — add, edit, remove, and test.
struct ServersSettingsView: View {
    @ObservedObject var monitor: ServiceMonitor
    @State private var servers: [ServerConnection]
    @State private var showingAddSheet = false
    @State private var editingServer: ServerConnection?
    @State private var testingServerID: UUID?
    @State private var testResult: String?

    init(monitor: ServiceMonitor) {
        self.monitor = monitor
        _servers = State(initialValue: monitor.currentConfig.servers)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach($servers) { $server in
                    ServerRow(
                        server: $server,
                        monitor: monitor,
                        testResult: server.id == testingServerID ? testResult : nil,
                        onEdit: { editingServer = server },
                        onDelete: { deleteServer(server) },
                        onTest: { testConnection(server) },
                        onToggle: { saveServers() }
                    )
                }
            }

            HStack {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }

                Spacer()
            }
            .padding(12)
        }
        .onAppear {
            servers = monitor.currentConfig.servers
        }
        .sheet(isPresented: $showingAddSheet) {
            ServerEditSheet(mode: .add) { server in
                servers.append(server)
                monitor.addServer(server)
            }
        }
        .sheet(item: $editingServer) { server in
            ServerEditSheet(mode: .edit(server)) { updated in
                if let index = servers.firstIndex(where: { $0.id == updated.id }) {
                    servers[index] = updated
                    monitor.updateServer(updated)
                }
            }
        }
    }

    private func deleteServer(_ server: ServerConnection) {
        servers.removeAll { $0.id == server.id }
        monitor.removeServer(server.id)
    }

    private func saveServers() {
        var config = monitor.currentConfig
        config.servers = servers
        monitor.updateConfig(config)
    }

    private func testConnection(_ server: ServerConnection) {
        testingServerID = server.id
        testResult = "Testing..."

        Task {
            let transport = SSHTransport()
            do {
                let data = try await transport.executeDockerCommand(
                    on: server,
                    dockerArgs: ["ps", "--format", "{{.Names}}"]
                )
                let names = String(data: data, encoding: .utf8)?
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ") ?? "none"

                await MainActor.run {
                    if server.id == testingServerID {
                        testResult = "Connected. Found: \(names.isEmpty ? "no containers" : names)"
                    }
                }
            } catch {
                await MainActor.run {
                    if server.id == testingServerID {
                        testResult = "Failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

// MARK: - Server Row

private struct ServerRow: View {
    @Binding var server: ServerConnection
    @ObservedObject var monitor: ServiceMonitor
    var testResult: String?
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onTest: () -> Void
    var onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("", isOn: $server.enabled)
                    .toggleStyle(.switch)
                    .onChange(of: server.enabled) { _, _ in onToggle() }

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.system(size: 13, weight: .medium))

                    HStack(spacing: 4) {
                        Text("\(server.username)@\(server.host):\(server.port)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        if server.usePassword {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                                .help("Password authentication")
                        }
                    }
                }

                Spacer()

                Button {
                    onTest()
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.diamond")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Test Connection")

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Edit Server")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Remove Server")
            }

            if let result = testResult {
                HStack(spacing: 4) {
                    Image(
                        systemName: result.hasPrefix("Connected") || result.hasPrefix("Testing")
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(result.hasPrefix("Connected") ? .green : result.hasPrefix("Testing") ? .blue : .red)

                    Text(result)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.leading, 44)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add / Edit Sheet

private struct ServerEditSheet: View {
    enum Mode {
        case add
        case edit(ServerConnection)
    }

    let mode: Mode
    let onSave: (ServerConnection) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var identityFile: String = ""
    @State private var usePassword: Bool = false
    @State private var password: String = ""
    @State private var showPassword: Bool = false

    private let serverID: UUID

    init(mode: Mode, onSave: @escaping (ServerConnection) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let server) = mode {
            _name = State(initialValue: server.name)
            _host = State(initialValue: server.host)
            _port = State(initialValue: String(server.port))
            _username = State(initialValue: server.username)
            _identityFile = State(initialValue: server.identityFile ?? "")
            _usePassword = State(initialValue: server.usePassword)
            serverID = server.id
            // Load existing password from Keychain
            if let existingPassword = KeychainHelper.retrievePassword(for: server.id) {
                _password = State(initialValue: existingPassword)
            }
        } else {
            serverID = UUID()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEdit ? "Edit Server" : "Add Server")
                .font(.headline)
                .padding()

            Divider()

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Host", text: $host)
                    .textFieldStyle(.roundedBorder)

                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)

                Toggle("Use password authentication", isOn: $usePassword)

                if usePassword {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if isEdit && !password.isEmpty {
                        Text("Password is stored securely in Keychain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    TextField("Identity File (optional)", text: $identityFile)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(name.isEmpty || host.isEmpty || username.isEmpty || (usePassword && password.isEmpty))
            }
            .padding()
        }
        .frame(width: 400)
    }

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func save() {
        let server = ServerConnection(
            id: serverID,
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: UInt16(port) ?? 22,
            username: username.trimmingCharacters(in: .whitespaces),
            identityFile: usePassword ? nil : (identityFile.trimmingCharacters(in: .whitespaces).isEmpty ? nil : identityFile.trimmingCharacters(in: .whitespaces)),
            usePassword: usePassword
        )

        // Store password in Keychain if password auth is enabled
        if usePassword && !password.isEmpty {
            _ = KeychainHelper.storePassword(for: serverID, password: password)
        } else if isEdit {
            // Clear password from Keychain if switching away from password auth
            _ = KeychainHelper.deletePassword(for: serverID)
        }

        onSave(server)
        dismiss()
    }
}
