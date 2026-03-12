import SwiftUI

/// agentch Design System — dark, glowy, AI-forward aesthetic.
enum DS {

    // MARK: - Color Palette

    /// Primary accent — electric blue
    static let accent = Color(red: 0.30, green: 0.58, blue: 1.0)
    /// Secondary accent — cyan highlight (outer glows, gradient endpoint)
    static let accentCyan = Color(red: 0.0, green: 0.82, blue: 1.0)
    /// Tertiary accent — purple depth (gradient endpoint)
    static let accentPurple = Color(red: 0.50, green: 0.30, blue: 1.0)

    /// Success — vivid green (status only)
    static let success = Color(red: 0.25, green: 0.90, blue: 0.50)
    /// Warning — rich amber
    static let warning = Color(red: 1.0, green: 0.62, blue: 0.15)

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

    /// Accent gradient — blue → cyan
    static let accentGradient = LinearGradient(
        colors: [accent, accentCyan],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Accent fill for primary buttons — blue → purple (vertical)
    static let accentFill = LinearGradient(
        colors: [accent.opacity(0.45), accentPurple.opacity(0.30)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Accent border for primary buttons
    static let accentBorder = LinearGradient(
        colors: [accent.opacity(0.65), accentPurple.opacity(0.30)],
        startPoint: .top,
        endPoint: .bottom
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
        /// Notch open — bouncy spring with slight overshoot (reverse curve feel)
        static let notchOpen: Animation = .spring(response: 0.45, dampingFraction: 0.62, blendDuration: 0.1)
        /// Notch close — snappy spring that pulls back into the notch
        static let notchClose: Animation = .spring(response: 0.30, dampingFraction: 0.72)
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
    @State private var rotation: Double = 0
    @State private var glowPhase = false

    var body: some View {
        Capsule(style: .continuous)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(colors: [
                        DS.accent,
                        DS.accentCyan,
                        DS.accentPurple.opacity(0.5),
                        DS.accent,
                    ]),
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: focused ? 1.5 : 1.0
            )
            .opacity(focused ? 0.85 : 0.35)
            // Layered glow — blue core, cyan mid, purple fringe
            .shadow(color: DS.accent.opacity(focused ? 0.55 : (glowPhase ? 0.14 : 0.08)),
                    radius: focused ? 8 : (glowPhase ? 5 : 3))
            .shadow(color: DS.accentCyan.opacity(focused ? 0.30 : (glowPhase ? 0.07 : 0.03)),
                    radius: focused ? 20 : (glowPhase ? 10 : 6))
            .shadow(color: DS.accentPurple.opacity(focused ? 0.14 : 0.02),
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
    let action: () -> Void

    var body: some View {
        let size: CGFloat = small ? 20 : 24
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: small ? 10 : 11, weight: .bold))
                .foregroundColor(isEmpty ? .white.opacity(0.12) : .white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isEmpty ? DS.surface2 : DS.accent)
                )
                .glow(isEmpty ? .clear : DS.accent, radius: 6)
        }
        .buttonStyle(DSButtonStyle())
        .disabled(isEmpty)
        .animation(DS.Anim.focus, value: isEmpty)
    }
}

// MARK: - Header Button

struct DSHeaderButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.white.opacity(isHovering ? 0.85 : 0.40))
                .frame(width: 22, height: 22)
                .animation(nil, value: icon)
                .fadedCircleSurface(interactive: true)
                .scaleEffect(isHovering ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Anim.hover) { isHovering = h } }
    }
}

// MARK: - Pill Button

struct DSPillButton<Label: View>: View {
    let action: () -> Void
    let fill: AnyShapeStyle
    let border: AnyShapeStyle
    let glowColor: Color?
    @ViewBuilder let label: () -> Label
    @State private var isHovering = false

    init(
        action: @escaping () -> Void,
        fill: some ShapeStyle = DS.surface1,
        border: some ShapeStyle = DS.border1,
        glowColor: Color? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.fill = AnyShapeStyle(fill)
        self.border = AnyShapeStyle(border)
        self.glowColor = glowColor
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.sp8 + 1)
                .background(Capsule(style: .continuous).fill(fill))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(border, lineWidth: 0.8)
                )
                .overlay(
                    // Hover highlight
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.04 : 0))
                )
                .if(glowColor != nil) { $0.glow(glowColor!, radius: isHovering ? 14 : 10) }
        }
        .buttonStyle(DSButtonStyle())
        .onHover { h in withAnimation(DS.Anim.hover) { isHovering = h } }
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
