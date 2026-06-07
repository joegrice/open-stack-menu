// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenStackMenu",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "OpenStackMenu",
            path: "Sources/OpenStackMenu"
        )
        // Note: Tests require Xcode for XCTest framework.
        // To enable tests, install Xcode and uncomment below:
        // .testTarget(
        //     name: "OpenStackMenuTests",
        //     dependencies: ["OpenStackMenu"],
        //     path: "Tests/OpenStackMenuTests"
        // )
    ]
)
