import SwiftUI

/// agentch Design System — dark, glowy, AI-forward aesthetic.
enum DS {

    // MARK: - Color Palette

    struct AgentPalette {
        let accent: Color
        let secondary: Color
    }

    // Claude brand colors from Mobbin
    static let claudeAccent = Color(red: 0.7569, green: 0.3725, blue: 0.2353)     // #C15F3C
    static let claudeSecondary = Color(red: 0.6941, green: 0.6784, blue: 0.6314)  // #B1ADA1
    static let claudePampas = Color(red: 0.9569, green: 0.9529, blue: 0.9333)     // #F4F3EE
    static let claudeWhite = Color.white                                              // #FFFFFF

    static let defaultAccent = claudeAccent
    static let defaultSecondary = claudeSecondary

    static func palette(for agentName: String) -> AgentPalette {
        _ = agentName
        return AgentPalette(accent: defaultAccent, secondary: defaultSecondary)
    }

    static func accent(for agentName: String) -> Color { palette(for: agentName).accent }
    static func secondary(for agentName: String) -> Color { palette(for: agentName).secondary }

    // Backward-compatible defaults for non-agent-specific UI elements.
    static let accent = defaultAccent
    static let accentCyan = defaultSecondary
    static let accentPurple = claudePampas

    /// Backward aliases that stay in Claude palette bounds.
    static let success = claudeAccent
    static let warning = claudeSecondary

    // MARK: Surfaces (on black background)

    static let surface1 = Color.white.opacity(0.04)
    static let surface2 = Color.white.opacity(0.07)
    static let surface3 = Color.white.opacity(0.10)

    // MARK: Borders

    static let border1 = Color.white.opacity(0.06)
    static let border2 = Color.white.opacity(0.10)

    // MARK: Text hierarchy

    static let text1 = Color.white.opacity(0.92)
    static let text2 = Color.white.opacity(0.55)
    static let text3 = Color.white.opacity(0.32)

    // MARK: - Gradients

    /// Accent gradient — default accent pair
    static let accentGradient = LinearGradient(
        colors: [claudeAccent, claudeSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func borderGradient(top: Double = 0.10, bottom: Double = 0.04) -> LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(top), Color.white.opacity(bottom)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func tintedFill(_ color: Color, top: Double = 0.30, bottom: Double = 0.18) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(top), color.opacity(bottom)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func tintedBorder(_ color: Color, top: Double = 0.40, bottom: Double = 0.15) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(top), color.opacity(bottom)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography

    enum Font {
        static let headline = SwiftUI.Font.system(size: 14, weight: .bold, design: .rounded)
        static let subheadline = SwiftUI.Font.system(size: 12.5, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 12.5, design: .rounded)
        static let bodyMedium = SwiftUI.Font.system(size: 12.5, weight: .medium, design: .rounded)
        static let caption = SwiftUI.Font.system(size: 11, design: .rounded)
        static let label = SwiftUI.Font.system(size: 11.5, weight: .semibold, design: .rounded)
        static let mono = SwiftUI.Font.system(size: 11.5, design: .monospaced)
        static let monoSmall = SwiftUI.Font.system(size: 10.5, design: .monospaced)
    }

    // MARK: - Animation Presets

    enum Anim {
        /// Notch open — interactive spring inspired by boring.notch
        static let notchOpen: Animation = .spring(response: 0.42, dampingFraction: 0.80, blendDuration: 0)
        /// Notch close — more damped to avoid bounce-back jitter
        static let notchClose: Animation = .spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
        /// Content fade in — smooth, no bounce
        static let contentIn: Animation = .easeOut(duration: 0.30).delay(0.06)
        /// Content fade out — quick fade before notch collapses
        static let contentOut: Animation = .easeOut(duration: 0.15)
        /// Expand/collapse content area — smooth spring
        static let expand: Animation = .spring(response: 0.42, dampingFraction: 0.82)
        /// Content height changes — responsive spring
        static let content: Animation = .spring(response: 0.35, dampingFraction: 0.88)
        /// Symbol transitions (SF Symbol morphs)
        static let symbol: Animation = .spring(response: 0.30, dampingFraction: 0.70)
        /// Hover feedback
        static let hover: Animation = .easeOut(duration: 0.15)
        static let focus: Animation = .easeOut(duration: 0.25)
        static let press: Animation = .spring(response: 0.2, dampingFraction: 0.6)
        static let pulse: Animation = .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        static let glow: Animation = .easeInOut(duration: 2.5).repeatForever(autoreverses: true)
        static let borderRotation: Animation = .linear(duration: 4).repeatForever(autoreverses: false)
        /// Staggered item entrance
        static func stagger(index: Int, base: Double = 0.05) -> Animation {
            .spring(response: 0.35, dampingFraction: 0.80).delay(Double(index) * base)
        }

        // Legacy aliases for backward compat
        static let appear = notchOpen
        static let dismiss = contentOut
    }

    // MARK: - Spacing & Radii

    static let sp2: CGFloat = 2
    static let sp4: CGFloat = 4
    static let sp6: CGFloat = 6
    static let sp8: CGFloat = 8
    static let sp10: CGFloat = 10
    static let sp12: CGFloat = 12
    static let sp14: CGFloat = 14
    static let sp16: CGFloat = 16
    static let sp18: CGFloat = 18
    static let sp20: CGFloat = 20
    static let sp24: CGFloat = 24

    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 18
    static let radiusXL: CGFloat = 22
}

// MARK: - Glow View Modifier

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.50), radius: radius * 0.35)
            .shadow(color: color.opacity(0.28), radius: radius)
            .shadow(color: color.opacity(0.12), radius: radius * 2.5)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 12) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - Button Styles

extension DS {
    enum ButtonVariant {
        case primary
        case secondary
    }
}

/// Standard press feedback — springy scale + dim + brief glow flash.
struct DSButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.80 : 1.0)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(DS.Anim.press, value: configuration.isPressed)
    }
}

// MARK: - Pulsing Status Dot

struct PulsingDot: View {
    let color: Color
    @State private var phase = false

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(color.opacity(phase ? 0.15 : 0.05))
                .frame(width: 16, height: 16)
            // Core dot
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .shadow(color: color.opacity(phase ? 0.70 : 0.30), radius: phase ? 8 : 4)
        .shadow(color: color.opacity(phase ? 0.30 : 0.10), radius: phase ? 16 : 8)
        .onAppear {
            withAnimation(DS.Anim.pulse) { phase = true }
        }
    }
}

// MARK: - Animated Glow Border (Input Field)

struct AnimatedGlowBorder: View {
    let focused: Bool
    let accent: Color
    let secondary: Color
    @State private var rotation: Double = 0
    @State private var glowPhase = false

    var body: some View {
        Capsule(style: .continuous)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(colors: [
                        accent,
                        secondary,
                        accent.opacity(0.55),
                        accent,
                    ]),
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: focused ? 1.5 : 1.0
            )
            .opacity(focused ? 0.85 : 0.35)
            .shadow(color: accent.opacity(focused ? 0.55 : (glowPhase ? 0.14 : 0.08)),
                    radius: focused ? 8 : (glowPhase ? 5 : 3))
            .shadow(color: secondary.opacity(focused ? 0.30 : (glowPhase ? 0.07 : 0.03)),
                    radius: focused ? 20 : (glowPhase ? 10 : 6))
            .shadow(color: accent.opacity(focused ? 0.14 : 0.02),
                    radius: focused ? 35 : 12)
            .animation(DS.Anim.focus, value: focused)
            .onAppear {
                withAnimation(DS.Anim.borderRotation) { rotation = 360 }
                withAnimation(DS.Anim.glow) { glowPhase = true }
            }
    }
}

// MARK: - Send Button

struct DSSendButton: View {
    let small: Bool
    let isEmpty: Bool
    let accent: Color
    let secondary: Color
    let action: () -> Void

    var body: some View {
        let size: CGFloat = small ? 20 : 24
        let variant: DS.ButtonVariant = isEmpty ? .secondary : .primary

        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: small ? 10 : 11, weight: .bold))
                .foregroundColor(variant == .primary ? .white : secondary.opacity(0.7))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(variant == .primary ? accent : .clear)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            variant == .primary ? accent.opacity(0.92) : secondary.opacity(0.60),
                            lineWidth: 0.9
                        )
                )
                .glow(variant == .primary ? accent : .clear, radius: 6)
        }
        .buttonStyle(DSButtonStyle())
        .disabled(isEmpty)
        .animation(DS.Anim.focus, value: isEmpty)
    }
}

// MARK: - Header Button

struct DSHeaderButton: View {
    let icon: String
    let variant: DS.ButtonVariant
    let accent: Color
    let secondary: Color
    let action: () -> Void
    @State private var isHovering = false

    init(
        icon: String,
        variant: DS.ButtonVariant = .secondary,
        accent: Color,
        secondary: Color,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.variant = variant
        self.accent = accent
        self.secondary = secondary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(variant == .primary ? accent : Color.white.opacity(0.001))
                Circle()
                    .strokeBorder(
                        variant == .primary ? accent.opacity(0.92) : secondary.opacity(0.58),
                        lineWidth: 0.9
                    )
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(variant == .primary ? .white : secondary.opacity(isHovering ? 0.95 : 0.72))
                    .animation(nil, value: icon)
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .scaleEffect(isHovering ? 1.08 : 1.0)
        }
        .contentShape(Rectangle())
        .buttonStyle(DSButtonStyle())
        .onHover { h in withAnimation(DS.Anim.hover) { isHovering = h } }
    }
}

// MARK: - Pill Button

struct DSPillButton<Label: View>: View {
    let action: () -> Void
    let variant: DS.ButtonVariant
    let accent: Color
    let secondary: Color
    let cornerRadius: CGFloat?
    @ViewBuilder let label: () -> Label
    @State private var isHovering = false

    init(
        action: @escaping () -> Void,
        variant: DS.ButtonVariant,
        accent: Color,
        secondary: Color,
        cornerRadius: CGFloat? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.variant = variant
        self.accent = accent
        self.secondary = secondary
        self.cornerRadius = cornerRadius
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            if let cornerRadius {
                labelBody
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(variant == .primary ? accent : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                variant == .primary ? accent.opacity(0.92) : secondary.opacity(0.58),
                                lineWidth: 0.9
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(isHovering ? 0.04 : 0))
                    )
            } else {
                labelBody
                    .background(
                        Capsule(style: .continuous)
                            .fill(variant == .primary ? accent : .clear)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                variant == .primary ? accent.opacity(0.92) : secondary.opacity(0.58),
                                lineWidth: 0.9
                            )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(isHovering ? 0.04 : 0))
                    )
            }
        }
        .buttonStyle(DSButtonStyle())
        .onHover { h in withAnimation(DS.Anim.hover) { isHovering = h } }
    }

    private var labelBody: some View {
        label()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.sp12)
            .padding(.vertical, DS.sp8 + 1)
            .foregroundColor(variant == .primary ? .white : secondary)
    }
}

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Pill & Button Background Modifiers (faded white on black)

private struct FadedRectModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }
}

private struct FadedCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }
}

private struct FadedCircleModifier: ViewModifier {
    let isInteractive: Bool

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(Color.white.opacity(isInteractive ? 0.10 : 0.08))
            )
    }
}

extension View {
    func fadedSurface(cornerRadius: CGFloat = DS.radiusM) -> some View {
        modifier(FadedRectModifier(cornerRadius: cornerRadius))
    }

    func fadedCapsuleSurface() -> some View {
        modifier(FadedCapsuleModifier())
    }

    func fadedCircleSurface(interactive: Bool = false) -> some View {
        modifier(FadedCircleModifier(isInteractive: interactive))
    }
}
