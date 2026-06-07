import SwiftUI

/// A small colored circle indicating container status.
struct StatusIndicatorView: View {
    let status: ContainerStatus

    @State private var isPulsing: Bool = false

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
            .overlay {
                if status == .online {
                    Circle()
                        .stroke(status.color.opacity(0.4), lineWidth: 1)
                        .frame(width: 10, height: 10)
                }
            }
            .opacity(isPulsing && status == .checking ? 0.3 : 1.0)
            .shadow(
                color: status == .online ? status.color.opacity(0.5) : .clear,
                radius: 3
            )
            .onAppear {
                if status == .checking {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: status) { _, newStatus in
                if newStatus == .checking {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }
}
