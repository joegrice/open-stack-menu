# Open Stack Menu

A macOS menu bar application that monitors Docker containers on home servers. Shows container status (online/offline/degraded) and provides quick links to open them in a browser.

## Features

- **Menu bar monitoring** — Live status of all Docker containers across multiple servers
- **Multi-server support** — Monitor containers on any number of remote Docker hosts via SSH
- **HTTP health checks** — Optional per-container health endpoint polling
- **Status indicators** — Visual color-coded status: green (online), red (offline), orange (degraded)
- **Compose project grouping** — Containers grouped by Docker Compose project
- **Per-container overrides** — Custom URLs, display names, and health check paths
- **SSH authentication** — Supports key-based auth (ssh-agent/1Password) and password auth (Keychain)
- **Launch at login** — Optional auto-start via macOS ServiceManagement
- **Zero dependencies** — Built entirely with system frameworks

## Requirements

- macOS 14.0+
- Swift 6.0+
- Remote servers running Docker with SSH access

## Build & Run

No Xcode required. Built via `swift build` + manual `.app` bundle assembly.

```sh
make build   # Release build
make debug   # Debug build
make run     # Launch the app
make install # Install to /Applications
make clean   # Remove build artifacts
```

## Configuration

Config is stored at `~/Library/Application Support/OpenStackMenu/config.json`. It is pretty-printed JSON and human-editable. A default config is created on first launch.

### Config Schema

```json
{
  "checkInterval": 60,
  "notifyOnStatusChange": false,
  "launchAtLogin": false,
  "servers": [
    {
      "id": "UUID",
      "name": "Home Server",
      "host": "192.168.1.100",
      "port": 22,
      "username": "admin",
      "enabled": true,
      "identityFile": null,
      "usePassword": false
    }
  ],
  "containerOverrides": [
    {
      "id": "container-id",
      "customURL": "http://example.com",
      "healthCheckPath": "/health",
      "enabled": true,
      "displayName": "My Service"
    }
  ]
}
```

## Architecture

### Data Flow

```
User's ~/.ssh/config + ssh-agent
        ↓
  SSHTransport (Process → ssh user@host docker ...)
        ↓
  DockerAPIClient (parses `docker ps --format '{{json .}}'` output)
        ↓
  ServiceMonitor (@MainActor ObservableObject)
        ↓  @Published
  SwiftUI Views (MenuBarView, ServiceRowView, SettingsView)
```

### Directory Structure

```
Sources/OpenStackMenu/
├── Models/
│   ├── AppConfig.swift          # App-wide configuration
│   ├── ContainerInfo.swift      # Container domain model
│   ├── ContainerStatus.swift    # Status enum + health check result
│   └── ServerConnection.swift   # SSH server connection config
├── Services/
│   ├── ConfigurationManager.swift  # JSON config read/write
│   ├── DockerAPIClient.swift       # Parses docker ps JSON output
│   ├── HealthChecker.swift         # HTTP health check service
│   ├── KeychainHelper.swift        # macOS Keychain password storage
│   ├── SSHTransport.swift          # Remote command execution via ssh
│   └── ServiceMonitor.swift        # Central @MainActor state manager
└── Views/
    ├── AboutView.swift             # About tab
    ├── ContainerOverrideView.swift # Per-container settings
    ├── GeneralSettingsView.swift   # General preferences
    ├── MenuBarView.swift           # Menu bar dropdown content
    ├── ServersSettingsView.swift   # Server CRUD + connection test
    ├── ServiceRowView.swift        # Single container row
    ├── SettingsView.swift          # Settings window container
    └── StatusIndicatorView.swift   # Pulsing status dot
```

### Status Model

- **Container state** (from Docker API): `running`, `exited`, `paused`
- **HTTP health check**: Optional, runs against a configurable path on running containers
- **Combined status**: online (running), offline (stopped/exited), degraded (running but health check failed)

## Authentication

### Key-Based (Default)

Uses the system `ssh` command with:
- `SSH_AUTH_SOCK` from the environment (works when launched from Terminal)
- Auto-discovery of 1Password SSH agent socket paths
- SSH connection multiplexing for performance

### Password-Based

When `usePassword` is enabled for a server:
- Password is stored securely in macOS Keychain
- `SSH_ASKPASS` helper script retrieves the password at runtime
- `PubkeyAuthentication` is disabled to avoid rejected key prompts

## Dependencies

**None.** Uses only system frameworks:
- `SwiftUI` — UI
- `Foundation` — Networking, JSON, file I/O
- `AppKit` — Activation policy, opening URLs
- `os` — Structured logging
- `ServiceManagement` — Launch at login (macOS 13+)
- `Security` — Keychain access

## License

MIT
