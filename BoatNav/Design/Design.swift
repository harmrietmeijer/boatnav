import SwiftUI
import UIKit

// MARK: - Design System

enum Design {

    // MARK: Colors
    enum Colors {
        // Brand — vibrant ocean-to-cyan gradient
        static let accent = Color(red: 0.0, green: 0.65, blue: 0.88)
        static let accentGradient = LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.70, blue: 0.95),
                Color(red: 0.25, green: 0.45, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        // Vivid secondary palette
        static let mint = Color(red: 0.15, green: 0.85, blue: 0.72)
        static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)
        static let violet = Color(red: 0.55, green: 0.35, blue: 0.95)
        static let amber = Color(red: 1.0, green: 0.72, blue: 0.20)
        static let sky = Color(red: 0.30, green: 0.78, blue: 1.0)

        // Semantic
        static let success = Color(red: 0.20, green: 0.82, blue: 0.55)
        static let warning = Color(red: 1.0, green: 0.72, blue: 0.20)
        static let danger = Color(red: 1.0, green: 0.38, blue: 0.38)

        // Surface
        static let cardBorder = Color.white.opacity(0.18)
        static let cardBorderDark = Color.white.opacity(0.08)
    }

    // MARK: Corner Radius
    enum Corner {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let pill: CGFloat = 100
    }

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    // MARK: Animation
    enum Animation {
        static let panel = SwiftUI.Animation.spring(duration: 0.4, bounce: 0.12)
        static let quick = SwiftUI.Animation.spring(duration: 0.25, bounce: 0.1)
        static let slow = SwiftUI.Animation.spring(duration: 0.5, bounce: 0.12)
    }

    // MARK: Touch
    enum Touch {
        static let minimum: CGFloat = 44
    }
}

// MARK: - View Modifiers

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = Design.Corner.medium

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Design.Colors.cardBorder, Design.Colors.cardBorderDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
    }
}

struct GroupedCard: ViewModifier {
    var cornerRadius: CGFloat = Design.Corner.medium

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Design.Colors.cardBorderDark, lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Design.Corner.medium) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func groupedCard(cornerRadius: CGFloat = Design.Corner.medium) -> some View {
        modifier(GroupedCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles

struct BoatNavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BoatNavButtonStyle {
    static var boatNav: BoatNavButtonStyle { BoatNavButtonStyle() }
}

// MARK: - Haptics

enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let warningGenerator = UINotificationFeedbackGenerator()

    static func selection() { selectionGenerator.selectionChanged() }
    static func light() { lightGenerator.impactOccurred() }
    static func medium() { mediumGenerator.impactOccurred() }
    static func warning() { warningGenerator.notificationOccurred(.warning) }
}
