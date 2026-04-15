import SwiftUI

struct MapButtonCluster: View {
    @Binding var activePanel: ActivePanel
    @EnvironmentObject var mapViewModel: MapViewModel

    var body: some View {
        VStack(spacing: Design.Spacing.sm) {
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
                action: { togglePanel(.locationSharing) }
            )

            MapButton(
                icon: "gearshape.fill",
                isActive: activePanel == .settings,
                action: { togglePanel(.settings) }
            )
        }
        .padding(.trailing, Design.Spacing.lg)
        .padding(.bottom, 160)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func togglePanel(_ panel: ActivePanel) {
        Haptics.selection()
        withAnimation(Design.Animation.panel) {
            activePanel = activePanel == panel ? .none : panel
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
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? Design.Blue.b5 : Design.Colors.text2)
                .frame(width: 42, height: 42)
                .background(
                    isActive ? Design.Ink.secondary : Design.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Design.Corner.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.Corner.md, style: .continuous)
                        .strokeBorder(
                            isActive ? Design.Blue.b3 : Design.Colors.borderMd,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.boatNav)
    }
}
