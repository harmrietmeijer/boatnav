import SwiftUI

struct MapSelectionBanner: View {
    let isSelectingStart: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 16, weight: .semibold))

            Text(isSelectingStart
                 ? "Tik op de kaart voor startlocatie"
                 : "Tik op de kaart voor bestemming")
                .font(.subheadline.weight(.medium))

            Spacer()

            Button("Annuleer") {
                onCancel()
            }
            .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }
}
