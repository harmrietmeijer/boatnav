import SwiftUI

struct ActiveNavigationStrip: View {
    let route: WaterwayRoute
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            onTap()
        } label: {
            HStack(spacing: Design.Spacing.md) {
                if let first = route.maneuvers.first {
                    maneuverIcon(for: first.type)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .tintedCard(
                            tint: Design.Blue.b1,
                            border: Design.Blue.b3,
                            cornerRadius: Design.Corner.sm
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let first = route.maneuvers.first {
                        Text(first.instruction)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Text(route.distanceString + " · " + route.timeString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Design.Blue.b6)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Design.Gray.g5)
            }
            .padding(.horizontal, Design.Spacing.lg)
            .padding(.vertical, Design.Spacing.md)
            .tintedCard(
                tint: Design.Ink.secondary,
                border: Color.white.opacity(0.06),
                cornerRadius: Design.Corner.lg
            )
        }
        .buttonStyle(.boatNav)
        .padding(.horizontal, Design.Spacing.lg)
    }

    @ViewBuilder
    private func maneuverIcon(for type: RouteManeuver.ManeuverType) -> some View {
        switch type {
        case .depart:
            Image(systemName: "location.fill").foregroundStyle(Design.Green.g5)
        case .turn(let direction):
            switch direction {
            case .left: Image(systemName: "arrow.turn.up.left").foregroundStyle(Design.Blue.b6)
            case .right: Image(systemName: "arrow.turn.up.right").foregroundStyle(Design.Blue.b6)
            case .slightLeft: Image(systemName: "arrow.up.left").foregroundStyle(Design.Blue.b6)
            case .slightRight: Image(systemName: "arrow.up.right").foregroundStyle(Design.Blue.b6)
            case .straight: Image(systemName: "arrow.up").foregroundStyle(Design.Blue.b6)
            }
        case .bridge:
            Image(systemName: "arrow.up.and.down.square.fill").foregroundStyle(Design.Amber.a5)
        case .lock:
            Image(systemName: "door.left.hand.closed").foregroundStyle(Design.Purple.p5)
        case .arrive:
            Image(systemName: "flag.checkered").foregroundStyle(Design.Red.r5)
        }
    }
}
