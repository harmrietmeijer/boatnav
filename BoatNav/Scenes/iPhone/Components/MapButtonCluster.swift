import SwiftUI

struct MapButtonCluster: View {
    @Binding var activePanel: ActivePanel

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            MapButton(
                icon: "location.fill",
                isActive: false,
                action: { /* re-center handled by map */ }
            )

            MapButton(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                isActive: activePanel == .navigation,
                action: { togglePanel(.navigation) }
            )

            MapButton(
                icon: "sailboat.fill",
                isActive: activePanel == .boatProfile,
                action: { togglePanel(.boatProfile) }
            )

            MapButton(
                icon: "gearshape.fill",
                isActive: activePanel == .settings,
                action: { togglePanel(.settings) }
            )
        }
        .padding(.trailing, 16)
        .padding(.bottom, 100)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func togglePanel(_ panel: ActivePanel) {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            if activePanel == panel {
                activePanel = .none
            } else {
                activePanel = panel
            }
        }
    }
}

struct MapButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(
                    isActive
                        ? AnyShapeStyle(Color.blue)
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Circle()
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
