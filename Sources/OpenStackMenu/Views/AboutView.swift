import SwiftUI

/// About this app.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundStyle(.primary)

            Text("Open Stack Menu")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .foregroundStyle(.secondary)

            Text("Monitor your home server Docker containers from the macOS menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            Text("Built with Swift + SwiftUI")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("MIT License")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
