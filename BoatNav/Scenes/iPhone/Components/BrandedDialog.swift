import SwiftUI

struct BrandedDialog<Content: View>: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    /// Optional: set to true for flitsmeister-style deep purple dialog
    var isFlitsStyle: Bool = false

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        Haptics.light()
                        onDismiss()
                    }

                VStack(spacing: 0) {
                    content()
                }
                .frame(maxWidth: 340)
                .background(
                    RoundedRectangle(cornerRadius: Design.Corner.xl, style: .continuous)
                        .fill(isFlitsStyle ? Color(hex: 0x120A28) : Design.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.Corner.xl, style: .continuous)
                        .strokeBorder(
                            isFlitsStyle ? Color(hex: 0x4A3090) : Design.Colors.border,
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: Design.Corner.xl, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 30, y: 10)
                .padding(.horizontal, Design.Spacing.xxl)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            .animation(Design.Animation.quick, value: isPresented)
        }
    }
}

// MARK: - Branded Alert

struct BrandedAlertContent: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let buttons: [BrandedAlertButton]

    var body: some View {
        VStack(spacing: Design.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(iconColor)
                .padding(.top, Design.Spacing.xxl)

            Text(title)
                .font(.headline)
                .foregroundStyle(Design.Colors.text)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Design.Colors.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Design.Spacing.xl)

            VStack(spacing: Design.Spacing.sm) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    alertButton(button)
                }
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.bottom, Design.Spacing.xl)
        }
    }

    @ViewBuilder
    private func alertButton(_ button: BrandedAlertButton) -> some View {
        Button {
            Haptics.selection()
            button.action()
        } label: {
            Text(button.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(buttonForeground(button.style))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(buttonBackground(button.style), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    button.style == .secondary
                        ? RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Design.Colors.borderMd, lineWidth: 1)
                        : nil
                )
        }
    }

    private func buttonForeground(_ style: BrandedAlertButton.Style) -> Color {
        switch style {
        case .primary: return Design.Blue.b5
        case .destructive: return Design.Red.r6
        case .secondary: return Design.Colors.text2
        }
    }

    private func buttonBackground(_ style: BrandedAlertButton.Style) -> Color {
        switch style {
        case .primary: return Design.Ink.secondary
        case .destructive: return Color(hex: 0x3A0A0A)
        case .secondary: return .clear
        }
    }
}

struct BrandedAlertButton {
    enum Style { case primary, secondary, destructive }
    let title: String
    let style: Style
    let action: () -> Void
}
