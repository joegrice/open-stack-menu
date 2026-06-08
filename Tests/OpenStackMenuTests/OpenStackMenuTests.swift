import XCTest
@testable import OpenStackMenu

final class OpenStackMenuTests: XCTestCase {
    func testDefaultConfig() throws {
        let config = AppConfig.defaultConfig
        XCTAssertEqual(config.checkInterval, 60)
        XCTAssertFalse(config.notifyOnStatusChange)
        XCTAssertTrue(config.servers.isEmpty)
    }

    func testServerConnectionSSHDestination() {
        let server = ServerConnection(
            name: "Test",
            host: "192.168.1.1",
            username: "admin"
        )
        XCTAssertEqual(server.sshDestination, "admin@192.168.1.1")
    }

    func testContainerBestPortPrefersPublic() {
        let container = ContainerInfo(
            id: "abc",
            name: "test",
            image: "nginx",
            state: "running",
            status: "Up 1h",
            ports: [
                .init(ip: "0.0.0.0", privatePort: 80, publicPort: 8080, type: "tcp"),
                .init(ip: nil, privatePort: 443, publicPort: nil, type: "tcp")
            ],
            composeProject: nil,
            labels: [:],
            serverID: UUID(),
            serverName: "Test"
        )
        XCTAssertEqual(container.bestPort, 8080)
    }

    func testContainerStatusColors() {
        XCTAssertEqual(ContainerStatus.online.color, .green)
        XCTAssertEqual(ContainerStatus.offline.color, .red)
        XCTAssertEqual(ContainerStatus.degraded.color, .orange)
        XCTAssertEqual(ContainerStatus.restarting.color, .orange)
        XCTAssertEqual(ContainerStatus.unknown.color, .gray)
        XCTAssertEqual(ContainerStatus.checking.color, .blue)
    }

    func testContainerStatusSymbols() {
        XCTAssertEqual(ContainerStatus.online.symbolName, "circle.fill")
        XCTAssertEqual(ContainerStatus.online.symbolColor, .green)
        XCTAssertEqual(ContainerStatus.offline.symbolName, "circle.fill")
        XCTAssertEqual(ContainerStatus.offline.symbolColor, .red)
        XCTAssertEqual(ContainerStatus.degraded.symbolName, "circle.fill")
        XCTAssertEqual(ContainerStatus.degraded.symbolColor, .orange)
        XCTAssertEqual(ContainerStatus.restarting.symbolName, "arrow.clockwise")
        XCTAssertEqual(ContainerStatus.restarting.symbolColor, .orange)
        XCTAssertEqual(ContainerStatus.unknown.symbolName, "circle")
        XCTAssertEqual(ContainerStatus.unknown.symbolColor, .gray)
        XCTAssertEqual(ContainerStatus.checking.symbolName, "circle.fill")
        XCTAssertEqual(ContainerStatus.checking.symbolColor, .blue)
    }

    func testContainerStatusEmoji() {
        XCTAssertEqual(ContainerStatus.online.emoji, "🟢")
        XCTAssertEqual(ContainerStatus.offline.emoji, "🔴")
        XCTAssertEqual(ContainerStatus.degraded.emoji, "🟠")
        XCTAssertEqual(ContainerStatus.restarting.emoji, "🟠")
        XCTAssertEqual(ContainerStatus.unknown.emoji, "⚪")
        XCTAssertEqual(ContainerStatus.checking.emoji, "🔵")
    }
}
