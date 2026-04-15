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
                // Next maneuver icon
                if let first = route.maneuvers.first {
                    maneuverIcon(for: first.type)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(
                            Design.Colors.accent.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: Design.Corner.small, style: .continuous)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let first = route.maneuvers.first {
                        Text(first.instruction)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    Text(route.distanceString + " · " + route.timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: Circle())
            }
            .padding(.horizontal, Design.Spacing.lg)
            .padding(.vertical, Design.Spacing.md)
            .glassCard(cornerRadius: Design.Corner.medium)
        }
        .buttonStyle(.boatNav)
        .padding(.horizontal, Design.Spacing.lg)
    }

    @ViewBuilder
    private func maneuverIcon(for type: RouteManeuver.ManeuverType) -> some View {
        switch type {
        case .depart:
            Image(systemName: "location.fill")
                .foregroundStyle(Design.Colors.success)
        case .turn(let direction):
            switch direction {
            case .left: Image(systemName: "arrow.turn.up.left").foregroundStyle(Design.Colors.accent)
            case .right: Image(systemName: "arrow.turn.up.right").foregroundStyle(Design.Colors.accent)
            case .slightLeft: Image(systemName: "arrow.up.left").foregroundStyle(Design.Colors.accent)
            case .slightRight: Image(systemName: "arrow.up.right").foregroundStyle(Design.Colors.accent)
            case .straight: Image(systemName: "arrow.up").foregroundStyle(Design.Colors.accent)
            }
        case .bridge:
            Image(systemName: "arrow.up.and.down.square.fill").foregroundStyle(Design.Colors.amber)
        case .lock:
            Image(systemName: "door.left.hand.closed").foregroundStyle(Design.Colors.violet)
        case .arrive:
            Image(systemName: "flag.checkered").foregroundStyle(Design.Colors.coral)
        }
    }
}
