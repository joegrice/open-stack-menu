# AGENTS.md — Open Stack Menu

## Project Overview

Open Stack Menu is a macOS menu bar application that monitors Docker containers on home servers. It shows container status (online/offline/degraded) and provides quick links to open them in a browser.

## Tech Stack

- **Language:** Swift 6.3+
- **UI Framework:** SwiftUI
- **Platform:** macOS 14+
- **Build System:** Swift Package Manager + Makefile
- **No Xcode required** — built via `swift build` + manual `.app` bundle assembly

## Build & Run

```sh
make build   # Release build
make debug   # Debug build
make test    # Run tests
make run     # Launch the app
make install # Install to /Applications
make clean   # Remove build artifacts
```

## Code Conventions

### Naming
- **Types:** PascalCase (`ServiceMonitor`, `ContainerInfo`)
- **Functions and properties:** camelCase (`loadConfig()`, `bestPort`)
- **Files:** Match the primary type they define

### Concurrency (Swift 6 Strict)
- All model types crossing actor boundaries must be `Sendable`
- UI-observable state annotated with `@MainActor`
- Network/system calls use `async/await`

### File Organization

```
Sources/OpenStackMenu/
├── Models/          # Data types: ServerConnection, ContainerInfo, ContainerStatus, AppConfig
├── Services/        # Business logic: SSHTransport, DockerAPIClient, HealthChecker, ServiceMonitor, ConfigurationManager
└── Views/           # SwiftUI views: MenuBarView, SettingsView, etc.
```

### Configuration
- Stored at `~/Library/Application Support/OpenStackMenu/config.json`
- JSON format, pretty-printed, human-editable
- Default config returned on first launch or when the config file is corrupt/missing

## Architecture

### Data Flow
```
User's ~/.ssh/config + ssh-agent
        ↓
  SSHTransport (Process → ssh user@host docker ...)
        ↓
  DockerAPIClient (parses `docker ps` JSON output)
        ↓
  ServiceMonitor (@MainActor ObservableObject)
        ↓  @Published
  SwiftUI Views (MenuBarView, ServiceRowView, SettingsView)
```

### Status Model
- **Container state** (from Docker API): `running`, `exited`, `paused`
- **HTTP health check**: Optional, runs against a configurable path on running containers
- **Combined status**: online (running), offline (stopped/exited), degraded (running but health check failed)

### Multi-Server
- Multiple Docker servers can be configured via SSH
- Each server has hostname, port, username, optional identity file
- Containers are grouped by server and Compose project

## Dependencies

**None.** Uses only system frameworks:
- `SwiftUI` — UI
- `Foundation` — Networking, JSON, file I/O
- `AppKit` — Activation policy, opening URLs
- `os` — Structured logging
- `ServiceManagement` — Launch at login (macOS 13+)
