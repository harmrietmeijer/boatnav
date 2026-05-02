import SwiftUI
import UIKit

// MARK: - Design System — Bootnav

enum Design {

    // MARK: - Palette (from design system document)

    enum Ink {
        static let primary   = Color(hex: 0x0B1929)
        static let secondary = Color(hex: 0x0D2135)
        static let tertiary  = Color(hex: 0x112840)
    }

    enum Blue {
        static let b1 = Color(hex: 0x042C53)
        static let b2 = Color(hex: 0x0C447C)
        static let b3 = Color(hex: 0x185FA5)
        static let b4 = Color(hex: 0x378ADD)
        static let b5 = Color(hex: 0x85B7EB)
        static let b6 = Color(hex: 0xB5D4F4)
        static let b7 = Color(hex: 0xE6F1FB)
    }

    enum Green {
        static let g1 = Color(hex: 0x04342C)
        static let g2 = Color(hex: 0x085041)
        static let g3 = Color(hex: 0x0F6E56)
        static let g4 = Color(hex: 0x1D9E75)
        static let g5 = Color(hex: 0x5DCAA5)
        static let g6 = Color(hex: 0x9FE1CB)
        static let g7 = Color(hex: 0xE1F5EE)
    }

    enum Amber {
        static let a1 = Color(hex: 0x412402)
        static let a2 = Color(hex: 0x633806)
        static let a3 = Color(hex: 0x854F0B)
        static let a4 = Color(hex: 0xBA7517)
        static let a5 = Color(hex: 0xEF9F27)
        static let a6 = Color(hex: 0xFAC775)
        static let a7 = Color(hex: 0xFAEEDA)
    }

    enum Red {
        static let r1 = Color(hex: 0x501313)
        static let r2 = Color(hex: 0x791F1F)
        static let r3 = Color(hex: 0xA32D2D)
        static let r4 = Color(hex: 0xE24B4A)
        static let r5 = Color(hex: 0xF09595)
        static let r6 = Color(hex: 0xF7C1C1)
        static let r7 = Color(hex: 0xFCEBEB)
    }

    enum Purple {
        static let p1 = Color(hex: 0x26215C)
        static let p2 = Color(hex: 0x3C3489)
        static let p3 = Color(hex: 0x534AB7)
        static let p4 = Color(hex: 0x7F77DD)
        static let p5 = Color(hex: 0xAFA9EC)
        static let p6 = Color(hex: 0xCECBF6)
        static let p7 = Color(hex: 0xEEEDFE)
    }

    enum Gray {
        static let g1 = Color(hex: 0x2C2C2A)
        static let g2 = Color(hex: 0x444441)
        static let g3 = Color(hex: 0x5F5E5A)
        static let g4 = Color(hex: 0x888780)
        static let g5 = Color(hex: 0xB4B2A9)
        static let g6 = Color(hex: 0xD3D1C7)
        static let g7 = Color(hex: 0xF1EFE8)
    }

    // MARK: - Semantic Colors

    enum Colors {
        static let bg       = Color(hex: 0xF7F6F2)
        static let surface  = Color.white
        static let border   = Color(hex: 0x0B1929).opacity(0.10)
        static let borderMd = Color(hex: 0x0B1929).opacity(0.18)

        static let text     = Color(hex: 0x0B1929)
        static let text2    = Color(hex: 0x3A5070)
        static let text3    = Color(hex: 0x7A90A8)

        // Semantic
        static let accent   = Blue.b4
        static let success  = Green.g4
        static let warning  = Amber.a4
        static let danger   = Red.r4
        static let flits    = Purple.p4

        // Legacy aliases (for existing code that references these)
        static let mint     = Green.g5
        static let coral    = Red.r4
        static let violet   = Purple.p4
        static let amber    = Amber.a5
        static let sky      = Blue.b5

        // Accent gradient (subtle)
        static let accentGradient = LinearGradient(
            colors: [Blue.b3, Blue.b4],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Card borders
        static let cardBorder     = Color(hex: 0x0B1929).opacity(0.10)
        static let cardBorderDark = Color(hex: 0x0B1929).opacity(0.18)
    }

    // MARK: - Theme: Navigation (dark overlays on map)

    enum Nav {
        static let statBg    = Color.white.opacity(0.10)
        static let dataText  = Color(hex: 0xE8F4FF)
        static let labelText = Blue.b6
    }

    // MARK: - Theme: Flitsmeister (deep purple)

    enum Flits {
        static let bg        = Color(hex: 0x0C0820)
        static let surface   = Color(hex: 0x1E1040)
        static let border    = Color(hex: 0x3C2875)
        static let toastBg   = Color(hex: 0x120A28)
    }

    // MARK: - Theme: Route Planning (warm parchment)

    enum Route {
        static let bg        = Color(hex: 0xF5F2EC)
        static let text      = Color(hex: 0x1A1008)
        static let text2     = Color(hex: 0x5A4020)
        static let text3     = Color(hex: 0x8A7060)
        static let border    = Color(hex: 0xD4C8B8)
        static let rowTint   = Color(hex: 0x8B6030).opacity(0.06)
        static let cta       = Color(hex: 0x8B3020)
        static let tideBg    = Color(hex: 0xFDF9F5)
        static let wpDot     = Color(hex: 0x6B4020)
    }

    // MARK: - Panel Theme

    enum PanelTheme {
        case standard   // white surface — settings, boat profile, paywall
        case navigation // dark ink — active navigation
        case flits      // deep purple — flitsmeister
        case route      // warm parchment — route planning

        var background: Color {
            switch self {
            case .standard: return Colors.surface
            case .navigation: return Ink.primary
            case .flits: return Flits.bg
            case .route: return Route.bg
            }
        }

        var handleColor: Color {
            switch self {
            case .standard: return Colors.borderMd
            case .navigation: return Color.white.opacity(0.15)
            case .flits: return Purple.p5.opacity(0.2)
            case .route: return Route.border
            }
        }

        var closeButtonBg: Color {
            switch self {
            case .standard: return Colors.bg
            case .navigation: return Color.white.opacity(0.08)
            case .flits: return Purple.p5.opacity(0.1)
            case .route: return Route.border.opacity(0.5)
            }
        }

        var closeButtonFg: Color {
            switch self {
            case .standard: return Colors.text3
            case .navigation: return Blue.b6
            case .flits: return Purple.p4
            case .route: return Route.text3
            }
        }

        var borderColor: Color {
            switch self {
            case .standard: return Colors.border
            case .navigation: return Color.white.opacity(0.06)
            case .flits: return Flits.border
            case .route: return Route.border
            }
        }
    }

    // MARK: - Corner Radius

    enum Corner {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
        static let pill: CGFloat = 100

        // Legacy aliases
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 18
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    // MARK: - Animation

    enum Animation {
        static let panel = SwiftUI.Animation.spring(duration: 0.35, bounce: 0.12)
        static let quick = SwiftUI.Animation.spring(duration: 0.2, bounce: 0.1)
        static let slow  = SwiftUI.Animation.spring(duration: 0.5, bounce: 0.12)
    }

    // MARK: - Touch

    enum Touch {
        static let minimum: CGFloat = 44
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - View Modifiers

/// Clean white card with subtle border — the primary card style
struct SurfaceCard: ViewModifier {
    var cornerRadius: CGFloat = Design.Corner.md

    func body(content: Content) -> some View {
        content
            .background(Design.Colors.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Design.Colors.border, lineWidth: 1)
            )
    }
}

/// Dark-tinted pill/card for status elements (like the design system pills)
struct TintedCard: ViewModifier {
    let tint: Color
    let borderColor: Color
    var cornerRadius: CGFloat = Design.Corner.md

    func body(content: Content) -> some View {
        content
            .background(tint, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    /// White surface card with 1px border
    func surfaceCard(cornerRadius: CGFloat = Design.Corner.md) -> some View {
        modifier(SurfaceCard(cornerRadius: cornerRadius))
    }

    /// Dark-tinted card for status/accent elements
    func tintedCard(tint: Color, border: Color, cornerRadius: CGFloat = Design.Corner.md) -> some View {
        modifier(TintedCard(tint: tint, borderColor: border, cornerRadius: cornerRadius))
    }

    /// Warm parchment card for route planning
    func routeCard(cornerRadius: CGFloat = Design.Corner.md) -> some View {
        self
            .background(Design.Route.rowTint, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Semi-transparent stat card for dark navigation overlay
    func navStatCard(cornerRadius: CGFloat = Design.Corner.sm) -> some View {
        self
            .background(Design.Nav.statBg, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // Legacy modifiers — map to surfaceCard
    func glassCard(cornerRadius: CGFloat = Design.Corner.md) -> some View {
        modifier(SurfaceCard(cornerRadius: cornerRadius))
    }

    func groupedCard(cornerRadius: CGFloat = Design.Corner.md) -> some View {
        modifier(SurfaceCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles

struct BoatNavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

/// Navy button — dark background, colored text (the primary style from the design system)
struct NavyButtonStyle: ButtonStyle {
    var textColor: Color = Design.Blue.b6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Design.Ink.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

/// Go button — dark green background, green text
struct GoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Design.Green.g6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: 0x073D1E), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

/// Danger button — dark red background, red text
struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Design.Red.r6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: 0x3A0A0A), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

/// Outline button — transparent with border
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Design.Colors.text2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Design.Colors.borderMd, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

/// Flitsmeister button — deep purple
struct FlitsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Design.Purple.p5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: 0x1A0835), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(hex: 0x3C2875), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BoatNavButtonStyle {
    static var boatNav: BoatNavButtonStyle { BoatNavButtonStyle() }
}
extension ButtonStyle where Self == NavyButtonStyle {
    static var navy: NavyButtonStyle { NavyButtonStyle() }
}
extension ButtonStyle where Self == GoButtonStyle {
    static var go: GoButtonStyle { GoButtonStyle() }
}
extension ButtonStyle where Self == DangerButtonStyle {
    static var danger: DangerButtonStyle { DangerButtonStyle() }
}
extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
}
extension ButtonStyle where Self == FlitsButtonStyle {
    static var flits: FlitsButtonStyle { FlitsButtonStyle() }
}

/// Route CTA — warm dark red-brown (#8B3020), white text
struct RouteCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Design.Route.cta, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

/// Route secondary — warm transparent border
struct RouteOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Design.Route.text2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Design.Route.rowTint,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(hex: 0x8B6030).opacity(0.2), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == RouteCTAButtonStyle {
    static var routeCTA: RouteCTAButtonStyle { RouteCTAButtonStyle() }
}
extension ButtonStyle where Self == RouteOutlineButtonStyle {
    static var routeOutline: RouteOutlineButtonStyle { RouteOutlineButtonStyle() }
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

// MARK: - Mono text helper

extension View {
    /// Apply monospaced design for data values
    func monoData() -> some View {
        self.font(.system(.body, design: .monospaced).weight(.bold))
    }
}
