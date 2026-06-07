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

### SwiftUI Observation Pattern
**Critical:** Menu bar apps are prone to infinite render loops when passing `@ObservedObject` down through multiple view layers. Always **snapshot** observable state into value-type properties at the top-level view and pass those down:

```swift
// MenuBarView — snapshot before passing to children
let statuses = monitor.statuses
let healthResults = monitor.healthResults
let overrides = monitor.currentConfig.containerOverrides
let servers = monitor.currentConfig.servers

// Child views receive plain `let` properties, not @ObservedObject
ServiceRowView(
    status: status,
    healthResult: healthResult,
    containerOverride: containerOverride,
    serverHost: serverHost,
    onOpen: { onOpen(container) }
)
```

### Keychain & Authentication
- Passwords stored in macOS Keychain via `KeychainHelper`
- Touch ID access control is attempted but **falls back gracefully** when unavailable (common with ad-hoc code signing)
- Failed Keychain operations are logged via `os.Logger` — UI does not show secondary error dialogs
- Inline password prompt (`NSAlert` with `NSSecureTextField`) is shown in the menu bar when a server has a password error
- `NSApp.activate(ignoringOtherApps:)` is called before showing alerts to ensure they appear in front

### Status Model
- **Container state** (from Docker API): `running`, `exited`, `paused`
- **HTTP health check**: Optional, runs against a configurable path on running containers
- **Combined status**: online (running), offline (stopped/exited), degraded (running but health check failed)
- **Port display**: All HTTP ports shown as badges (`public:private` format); degraded status shows orange subtitle with health error message

### Multi-Server
- Multiple Docker servers can be configured via SSH
- Each server has hostname, port, username, optional identity file
- Containers are grouped by server and Compose project

## Dependencies

**None.** Uses only system frameworks:
- `SwiftUI` — UI
- `Foundation` — Networking, JSON, file I/O
- `AppKit` — Activation policy, opening URLs, alerts
- `os` — Structured logging
- `Security` — Keychain operations
- `LocalAuthentication` — Touch ID / biometric authentication
- `ServiceManagement` — Launch at login (macOS 13+)
