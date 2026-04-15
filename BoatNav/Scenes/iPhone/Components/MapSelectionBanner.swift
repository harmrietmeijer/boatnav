import SwiftUI

struct MapSelectionBanner: View {
    let isSelectingStart: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Design.Spacing.md) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: Design.Corner.small, style: .continuous))

            Text(isSelectingStart
                 ? "Tik op de kaart voor startlocatie"
                 : "Tik op de kaart voor bestemming")
                .font(.subheadline.weight(.medium))

            Spacer()

            Button("Annuleer") {
                Haptics.light()
                onCancel()
            }
            .font(.subheadline.bold())
            .padding(.horizontal, Design.Spacing.md)
            .padding(.vertical, Design.Spacing.xs + 2)
            .background(.white.opacity(0.2), in: Capsule())
        }
        .padding(.horizontal, Design.Spacing.lg)
        .padding(.vertical, Design.Spacing.md)
        .foregroundStyle(.white)
        .background(
            Design.Colors.accentGradient,
            in: RoundedRectangle(cornerRadius: Design.Corner.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.Corner.medium, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: Design.Colors.accent.opacity(0.3), radius: 12, y: 4)
        .padding(.horizontal, Design.Spacing.lg)
    }
}
