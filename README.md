<p align="center">
  <h1 align="center">Open Stack Menu</h1>
  <p align="center">
    A macOS menu bar app to monitor your Docker containers at a glance.
  </p>
</p>

<p align="center">
  <img src="assets/screenshot.png" alt="Open Stack Menu screenshot" width="138" />
</p>

<p align="center">
  <a href="https://swiftpackageindex.com/joe/open-stack-menu">
    <img src="https://img.shields.io/badge/Swift-6.3+-orange.svg" alt="Swift 6.3+" />
  </a>
  <a href="https://github.com/joe/open-stack-menu/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License" />
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2014+-lightgrey.svg" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/dependencies-none-green.svg" alt="No dependencies" />
</p>

---

![alt text](image.png)

## Features

- [x] **Menu bar monitoring** — Live status of all Docker containers across multiple servers
- [x] **Multi-server support** — Monitor any number of remote Docker hosts via SSH
- [x] **HTTP health checks** — Per-container health endpoint polling with degraded state
- [x] **Color-coded status** — Green (online), red (offline), orange (degraded)
- [x] **Compose grouping** — Containers grouped by Docker Compose project
- [x] **Per-container overrides** — Custom URLs, display names, and health check paths
- [x] **SSH authentication** — Key-based (ssh-agent / 1Password) and password-based (Keychain)
- [x] **Launch at login** — Auto-start via macOS ServiceManagement
- [x] **Zero dependencies** — Built entirely with Apple system frameworks

## Requirements

- macOS 14.0+
- Swift 6.3+ (to build from source)
- Remote servers running Docker with SSH access

## Installation

### Build from source

No Xcode required — uses `swift build` + manual `.app` bundle assembly.

```sh
git clone https://github.com/joe/open-stack-menu.git
cd open-stack-menu
make build    # Release build
make run      # Launch the app
make install  # Install to /Applications
```

## Configuration

Config lives at `~/Library/Application Support/OpenStackMenu/config.json` and is human-editable JSON. A default config is created on first launch.

Add your servers in Settings, or edit the config directly:

```json
{
  "checkInterval": 60,
  "servers": [
    {
      "name": "Home Server",
      "host": "192.168.1.100",
      "port": 22,
      "username": "admin",
      "enabled": true
    }
  ]
}
```

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

For development guidelines and architecture details, see [AGENTS.md](AGENTS.md).

## License

Open Stack Menu is available under the [MIT License](LICENSE).
