import SwiftUI

struct MapSelectionBanner: View {
    let isSelectingStart: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Design.Spacing.md) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))

            Text(isSelectingStart
                 ? "Tik op de kaart voor startlocatie"
                 : "Tik op de kaart voor bestemming")
                .font(.subheadline.weight(.medium))

            Spacer()

            Button("Annuleer") {
                Haptics.light()
                onCancel()
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Design.Spacing.md)
            .padding(.vertical, Design.Spacing.xs + 2)
            .background(Design.Blue.b3.opacity(0.3), in: Capsule())
        }
        .padding(.horizontal, Design.Spacing.lg)
        .padding(.vertical, Design.Spacing.md)
        .foregroundStyle(Design.Blue.b5)
        .tintedCard(
            tint: Design.Ink.secondary,
            border: Color(hex: 0x1E4060),
            cornerRadius: Design.Corner.md
        )
        .padding(.horizontal, Design.Spacing.lg)
    }
}
