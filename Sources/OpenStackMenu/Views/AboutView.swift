import SwiftUI

/// About this app.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            Image(systemName: "server.rack")
                .font(.system(size: 52))
                .foregroundStyle(.primary)

            Text("Open Stack Menu")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .foregroundStyle(.secondary)

            Text("Monitor your home server Docker containers from the macOS menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()

            Text("Built with Swift + SwiftUI")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("MIT License")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
