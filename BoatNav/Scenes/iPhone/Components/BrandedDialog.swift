import SwiftUI

struct BrandedDialog<Content: View>: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isPresented {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        Haptics.light()
                        onDismiss()
                    }

                // Dialog card
                VStack(spacing: 0) {
                    content()
                }
                .frame(maxWidth: 340)
                .glassCard(cornerRadius: Design.Corner.large)
                .clipShape(RoundedRectangle(cornerRadius: Design.Corner.large, style: .continuous))
                .padding(.horizontal, Design.Spacing.xxl)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            .animation(Design.Animation.quick, value: isPresented)
        }
    }
}

// MARK: - Branded Alert (simple title + message + buttons)

struct BrandedAlertContent: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let buttons: [BrandedAlertButton]

    var body: some View {
        VStack(spacing: Design.Spacing.lg) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(iconColor)
                .padding(.top, Design.Spacing.xxl)

            // Title
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Design.Spacing.xl)

            // Buttons
            VStack(spacing: Design.Spacing.sm) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    Button {
                        Haptics.selection()
                        button.action()
                    } label: {
                        Text(button.title)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                button.style == .primary
                                    ? AnyShapeStyle(Design.Colors.accent)
                                    : button.style == .destructive
                                        ? AnyShapeStyle(Design.Colors.danger.opacity(0.1))
                                        : AnyShapeStyle(.quaternary),
                                in: RoundedRectangle(cornerRadius: Design.Corner.small)
                            )
                            .foregroundStyle(
                                button.style == .primary ? .white
                                    : button.style == .destructive ? Design.Colors.danger
                                    : .primary
                            )
                    }
                }
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.bottom, Design.Spacing.xl)
        }
    }
}

struct BrandedAlertButton {
    enum Style { case primary, secondary, destructive }
    let title: String
    let style: Style
    let action: () -> Void
}
