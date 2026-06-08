import AppKit

// Install crash handlers before anything else
CrashHandler.install()

// Hide the dock icon before launching the SwiftUI app
NSApplication.shared.setActivationPolicy(.accessory)
OpenStackMenuApp.main()
