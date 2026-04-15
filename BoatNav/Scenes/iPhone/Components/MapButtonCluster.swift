import SwiftUI

struct MapButtonCluster: View {
    @Binding var activePanel: ActivePanel
    @EnvironmentObject var mapViewModel: MapViewModel

    var body: some View {
        VStack(spacing: Design.Spacing.md) {
            Spacer()

            MapButton(
                icon: "location.fill",
                isActive: false,
                action: { mapViewModel.recenterTrigger = true }
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
                icon: "person.2.fill",
                isActive: activePanel == .locationSharing,
                accentColor: Design.Colors.mint,
                action: { togglePanel(.locationSharing) }
            )

            MapButton(
                icon: "gearshape.fill",
                isActive: activePanel == .settings,
                action: { togglePanel(.settings) }
            )
        }
        .padding(.trailing, Design.Spacing.lg)
        .padding(.bottom, 100)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func togglePanel(_ panel: ActivePanel) {
        Haptics.selection()
        withAnimation(Design.Animation.panel) {
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
    var accentColor: Color = Design.Colors.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? .white : .primary)
                .frame(width: Design.Touch.minimum, height: Design.Touch.minimum)
                .background(
                    isActive
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                          )
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isActive ? .white.opacity(0.25) : Design.Colors.cardBorderDark,
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        }
        .buttonStyle(.boatNav)
    }
}
