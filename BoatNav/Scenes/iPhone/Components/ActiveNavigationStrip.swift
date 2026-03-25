import SwiftUI

struct ActiveNavigationStrip: View {
    let route: WaterwayRoute
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Next maneuver icon
                if let first = route.maneuvers.first {
                    maneuverIcon(for: first.type)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let first = route.maneuvers.first {
                        Text(first.instruction)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    Text(route.distanceString + " · " + route.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func maneuverIcon(for type: RouteManeuver.ManeuverType) -> some View {
        switch type {
        case .depart:
            Image(systemName: "location.fill")
                .foregroundStyle(.green)
        case .turn(let direction):
            switch direction {
            case .left: Image(systemName: "arrow.turn.up.left").foregroundStyle(.blue)
            case .right: Image(systemName: "arrow.turn.up.right").foregroundStyle(.blue)
            case .slightLeft: Image(systemName: "arrow.up.left").foregroundStyle(.blue)
            case .slightRight: Image(systemName: "arrow.up.right").foregroundStyle(.blue)
            case .straight: Image(systemName: "arrow.up").foregroundStyle(.blue)
            }
        case .bridge:
            Image(systemName: "arrow.up.and.down.square.fill").foregroundStyle(.orange)
        case .lock:
            Image(systemName: "door.left.hand.closed").foregroundStyle(.purple)
        case .arrive:
            Image(systemName: "flag.checkered").foregroundStyle(.red)
        }
    }
}
