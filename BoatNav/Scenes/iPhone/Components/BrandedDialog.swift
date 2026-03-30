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
                    .onTapGesture { onDismiss() }

                // Dialog card
                VStack(spacing: 0) {
                    content()
                }
                .frame(maxWidth: 340)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 28)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            .animation(.spring(duration: 0.3, bounce: 0.15), value: isPresented)
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
        VStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(iconColor)
                .padding(.top, 24)

            // Title
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Buttons
            VStack(spacing: 8) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    Button {
                        button.action()
                    } label: {
                        Text(button.title)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                button.style == .primary
                                    ? AnyShapeStyle(.blue)
                                    : button.style == .destructive
                                        ? AnyShapeStyle(.red.opacity(0.1))
                                        : AnyShapeStyle(.quaternary),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .foregroundStyle(
                                button.style == .primary ? .white
                                    : button.style == .destructive ? .red
                                    : .primary
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct BrandedAlertButton {
    enum Style { case primary, secondary, destructive }
    let title: String
    let style: Style
    let action: () -> Void
}
