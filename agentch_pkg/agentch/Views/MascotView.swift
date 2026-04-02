import SwiftUI

struct MascotView: View {
    let agentType: AgentType
    let status: SessionStatus
    let size: CGFloat

    @State private var animationPhase: CGFloat = 0
    @State private var breathe: CGFloat = 0

    private let bubbleWidth: CGFloat = 14

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            mascotShape
                .opacity(status == .idle ? 0.5 : 1.0)
                .scaleEffect(thinkingScale + breathe * 0.02)
                .offset(y: thinkingBounce)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                .frame(width: size, height: size)

            // Fixed-width slot for bubble/zzz — always reserved
            ZStack {
                if status == .thinking {
                    ThinkingBubble()
                        .transition(.blurReplace)
                }
                if status == .waiting {
                    SleepingZzz()
                        .transition(.blurReplace)
                }
            }
            .frame(width: bubbleWidth)
            .offset(y: -4)
        }
        .onAppear {
            if status == .thinking {
                startThinkingAnimation()
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathe = 1
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus == .thinking {
                startThinkingAnimation()
            } else {
                withAnimation(.spring(duration: 0.3)) {
                    animationPhase = 0
                }
            }
        }
    }

    private func startThinkingAnimation() {
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            animationPhase = 1
        }
    }

    private var thinkingScale: CGFloat {
        status == .thinking ? 1.0 + animationPhase * 0.05 : 1.0
    }

    private var thinkingBounce: CGFloat {
        status == .thinking ? -animationPhase * 1.5 : 0
    }

    @ViewBuilder
    private var mascotShape: some View {
        switch agentType {
        case .claude:
            ClawdMascot(status: status, animationPhase: animationPhase)
        case .codex:
            CodexMascot(status: status, animationPhase: animationPhase)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.gray)
                .padding(4)
        }
    }
}

/// Cloud-style thought bubble with animated dots.
struct ThinkingBubble: View {
    @State private var dotPhase: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1.5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.primary)
                        .frame(width: 2, height: 2)
                        .opacity(dotPhase == i ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 3.5)
            .padding(.vertical, 2.5)
            .background(
                Capsule().fill(.primary.opacity(0.15))
            )

            HStack(spacing: 1.5) {
                Spacer().frame(width: 1.5)
                Circle()
                    .fill(.primary.opacity(0.12))
                    .frame(width: 3, height: 3)
                Circle()
                    .fill(.primary.opacity(0.08))
                    .frame(width: 2, height: 2)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}

/// Animated Zzz floating up when sleeping/waiting.
struct SleepingZzz: View {
    @State private var phase: CGFloat = 0

    private let darkBlue = Color(red: 0.15, green: 0.15, blue: 0.4)
    private let yellow = Color(red: 1.0, green: 0.85, blue: 0.2)

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                ZStack {
                    // Yellow stroke (rendered as shadow on all sides)
                    Text("z")
                        .font(.system(size: CGFloat(3 + i), weight: .black, design: .rounded))
                        .foregroundStyle(yellow.opacity(0.4))
                        .shadow(color: yellow.opacity(0.3), radius: 0.2)
                    // Dark blue fill on top
                    Text("z")
                        .font(.system(size: CGFloat(3 + i), weight: .black, design: .rounded))
                        .foregroundStyle(darkBlue)
                        .padding(0.5)
                }
                .offset(
                    x: CGFloat(i) * 2 + sin(phase * .pi + CGFloat(i)) * 1.5,
                    y: -CGFloat(i) * 3 - phase * 1.5
                )
                .opacity(1.0 - phase * 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

/// Pulsing status indicator dot with glow ring for waiting.
struct StatusDot: View {
    let status: SessionStatus
    @State private var pulse = false

    private var shouldPulse: Bool {
        status == .thinking || status == .waiting
    }

    var body: some View {
        ZStack {
            // Glow ring for waiting
            if status == .waiting {
                Circle()
                    .stroke(color.opacity(pulse ? 0.4 : 0.1), lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            }

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .scaleEffect(shouldPulse && pulse ? 1.3 : 1.0)
                .animation(
                    shouldPulse
                        ? .easeInOut(duration: status == .waiting ? 1.2 : 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )
        }
        .frame(width: 12, height: 12)
        .onAppear {
            if shouldPulse { pulse = true }
        }
        .onChange(of: status) { _, _ in
            pulse = shouldPulse
        }
    }

    private var color: Color {
        switch status {
        case .thinking: return .green
        case .waiting: return .orange
        case .idle: return .gray.opacity(0.6)
        case .error: return .red
        }
    }
}

/// Clawd mascot — pixel-art Claude character.
struct ClawdMascot: View {
    let status: SessionStatus
    let animationPhase: CGFloat

    private let bodyColor = Color(red: 0.855, green: 0.467, blue: 0.345)

    private let legColor = Color(red: 0.75, green: 0.38, blue: 0.27)

    @State private var showSitting = false

    var body: some View {
        ZStack {
            // Sitting (behind)
            ClawdSittingLegsShape()
                .fill(legColor)
                .opacity(showSitting ? 1 : 0)
            ClawdSittingBodyShape()
                .fill(bodyColor)
                .opacity(showSitting ? 1 : 0)
            ClawdSittingEyesShape()
                .fill(.black)
                .opacity(showSitting ? 1 : 0)

            // Standing (front)
            ClawdBodyShape()
                .fill(status == .error ? .red : bodyColor)
                .opacity(showSitting ? 0 : 1)
            ClawdEyesShape(animationPhase: eyePhase)
                .fill(.black)
                .opacity(showSitting ? 0 : 1)
        }
        .aspectRatio(490.0 / 385.0, contentMode: .fit)
        .onChange(of: status) { _, newStatus in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showSitting = newStatus == .waiting
            }
        }
        .onAppear { showSitting = status == .waiting }
    }

    private var eyePhase: CGFloat {
        switch status {
        case .thinking: return animationPhase
        case .waiting: return 0
        case .idle, .error: return 0
        }
    }
}

/// Legs for sitting Clawd — extend forward, drawn behind body with darker shade.
struct ClawdSittingLegsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        var p = Path()
        // Left pair of legs — extend to the left from body bottom
        p.addRect(CGRect(x: -50, y: 245, width: 140, height: 45))
        p.addRect(CGRect(x: -50, y: 300, width: 140, height: 45))
        // Right pair of legs — extend to the right from body bottom
        p.addRect(CGRect(x: 400, y: 245, width: 140, height: 45))
        p.addRect(CGRect(x: 400, y: 300, width: 140, height: 45))
        return p.applying(t)
    }
}

/// Body for sitting Clawd — same as standing but without the leg portions.
struct ClawdSittingBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        var p = Path()
        // Same body as standing, but legs stop at the body bottom (288.5)
        // and a flat bottom sits on the "ground"
        p.move(to: CGPoint(x: 45, y: 350))
        p.addLine(to: CGPoint(x: 45, y: 192))
        p.addLine(to: CGPoint(x: 0, y: 192))
        p.addLine(to: CGPoint(x: 0, y: 96))
        p.addLine(to: CGPoint(x: 45, y: 96))
        p.addLine(to: CGPoint(x: 45, y: 0))
        p.addLine(to: CGPoint(x: 445, y: 0))
        p.addLine(to: CGPoint(x: 445, y: 96))
        p.addLine(to: CGPoint(x: 490, y: 96))
        p.addLine(to: CGPoint(x: 490, y: 192))
        p.addLine(to: CGPoint(x: 445, y: 192))
        p.addLine(to: CGPoint(x: 445, y: 350))
        p.closeSubpath()
        return p.applying(t)
    }
}

/// Eyes for sitting Clawd — half-closed/sleepy.
struct ClawdSittingEyesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        let eyeHeight: CGFloat = 15
        let eyeY: CGFloat = 120

        var p = Path()
        p.addRect(CGRect(x: 89, y: eyeY, width: 45.5, height: eyeHeight))
        p.addRect(CGRect(x: 355, y: eyeY, width: 45.5, height: eyeHeight))
        return p.applying(t)
    }
}

struct ClawdBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        var p = Path()
        p.move(to: CGPoint(x: 89.5, y: 384.5))
        p.addLine(to: CGPoint(x: 45, y: 384.5))
        p.addLine(to: CGPoint(x: 45, y: 192))
        p.addLine(to: CGPoint(x: 0, y: 192))
        p.addLine(to: CGPoint(x: 0, y: 96))
        p.addLine(to: CGPoint(x: 45, y: 96))
        p.addLine(to: CGPoint(x: 45, y: 0))
        p.addLine(to: CGPoint(x: 445, y: 0))
        p.addLine(to: CGPoint(x: 445, y: 96))
        p.addLine(to: CGPoint(x: 490, y: 96))
        p.addLine(to: CGPoint(x: 490, y: 192))
        p.addLine(to: CGPoint(x: 445, y: 192))
        p.addLine(to: CGPoint(x: 445, y: 384.5))
        p.addLine(to: CGPoint(x: 400.5, y: 384.5))
        p.addLine(to: CGPoint(x: 400.5, y: 288.5))
        p.addLine(to: CGPoint(x: 356.5, y: 288.5))
        p.addLine(to: CGPoint(x: 356.5, y: 384.5))
        p.addLine(to: CGPoint(x: 312, y: 384.5))
        p.addLine(to: CGPoint(x: 312, y: 288.5))
        p.addLine(to: CGPoint(x: 178, y: 288.5))
        p.addLine(to: CGPoint(x: 178, y: 384.5))
        p.addLine(to: CGPoint(x: 133.5, y: 384.5))
        p.addLine(to: CGPoint(x: 133.5, y: 288.5))
        p.addLine(to: CGPoint(x: 89.5, y: 288.5))
        p.closeSubpath()
        return p.applying(t)
    }
}

struct ClawdEyesShape: Shape {
    var animationPhase: CGFloat

    var animatableData: CGFloat {
        get { animationPhase }
        set { animationPhase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        // Positive phase = squint (blink), negative phase = wide open
        let scale = 1.0 - animationPhase * 0.7
        let eyeHeight: CGFloat = 48.5 * max(scale, 0.1)
        let eyeYOffset: CGFloat = (48.5 - eyeHeight) / 2

        var p = Path()
        p.addRect(CGRect(x: 89, y: 95 + eyeYOffset, width: 45.5, height: eyeHeight))
        p.addRect(CGRect(x: 355, y: 95 + eyeYOffset, width: 45.5, height: eyeHeight))
        return p.applying(t)
    }
}

// MARK: - Codex Mascot

/// Codex mascot — pixel-art character with purple-blue gradient and > eye.
struct CodexMascot: View {
    let status: SessionStatus
    let animationPhase: CGFloat

    private let gradientTop = Color(red: 0.788, green: 0.588, blue: 0.961)    // #C996F5
    private let gradientBottom = Color(red: 0.294, green: 0.298, blue: 0.922)  // #4B4CEB
    private let darkLeg = Color(red: 0.22, green: 0.22, blue: 0.7)

    @State private var showSitting = false

    private var gradient: LinearGradient {
        LinearGradient(
            colors: status == .error ? [.red, .red] : [gradientTop, gradientBottom],
            startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            // Sitting
            CodexSittingLegsShape()
                .fill(darkLeg)
                .opacity(showSitting ? 1 : 0)
            CodexSittingBodyShape()
                .fill(gradient)
                .opacity(showSitting ? 1 : 0)
            CodexSittingFaceShape()
                .fill(.white.opacity(0.9))
                .opacity(showSitting ? 1 : 0)

            // Standing
            CodexBodyShape()
                .fill(gradient)
                .opacity(showSitting ? 0 : 1)
            CodexFaceShape(animationPhase: status == .thinking ? animationPhase : 0)
                .fill(.white.opacity(0.9))
                .opacity(showSitting ? 0 : 1)
        }
        .aspectRatio(490.0 / 385.0, contentMode: .fit)
        .onChange(of: status) { _, newStatus in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showSitting = newStatus == .waiting
            }
        }
        .onAppear { showSitting = status == .waiting }
    }
}

/// Codex body — same pixel-art shape as Clawd but with the Codex gradient.
struct CodexBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        var p = Path()
        // Outer body (same as Clawd standing)
        p.move(to: CGPoint(x: 45, y: 0))
        p.addLine(to: CGPoint(x: 445, y: 0))
        p.addLine(to: CGPoint(x: 445, y: 96))
        p.addLine(to: CGPoint(x: 490, y: 96))
        p.addLine(to: CGPoint(x: 490, y: 192))
        p.addLine(to: CGPoint(x: 445, y: 192))
        p.addLine(to: CGPoint(x: 445, y: 384.5))
        p.addLine(to: CGPoint(x: 400.5, y: 384.5))
        p.addLine(to: CGPoint(x: 400.5, y: 288.5))
        p.addLine(to: CGPoint(x: 356.5, y: 288.5))
        p.addLine(to: CGPoint(x: 356.5, y: 384.5))
        p.addLine(to: CGPoint(x: 312, y: 384.5))
        p.addLine(to: CGPoint(x: 312, y: 288.5))
        p.addLine(to: CGPoint(x: 178, y: 288.5))
        p.addLine(to: CGPoint(x: 178, y: 384.5))
        p.addLine(to: CGPoint(x: 133.5, y: 384.5))
        p.addLine(to: CGPoint(x: 133.5, y: 288.5))
        p.addLine(to: CGPoint(x: 89.5, y: 288.5))
        p.addLine(to: CGPoint(x: 89.5, y: 384.5))
        p.addLine(to: CGPoint(x: 45, y: 384.5))
        p.addLine(to: CGPoint(x: 45, y: 192))
        p.addLine(to: CGPoint(x: 0, y: 192))
        p.addLine(to: CGPoint(x: 0, y: 96))
        p.addLine(to: CGPoint(x: 45, y: 96))
        p.closeSubpath()
        return p.applying(t)
    }
}

/// Codex face — the > chevron and smile from the SVG.
/// Animates: chevron pulses when thinking.
struct CodexFaceShape: Shape {
    var animationPhase: CGFloat

    var animatableData: CGFloat {
        get { animationPhase }
        set { animationPhase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        var p = Path()

        // > chevron eye (from SVG path, simplified)
        // The SVG has a complex bezier for the > shape. Simplified as lines:
        let pulseOffset = animationPhase * 5
        p.move(to: CGPoint(x: 140 - pulseOffset, y: 72))
        p.addLine(to: CGPoint(x: 200, y: 142))
        p.addLine(to: CGPoint(x: 140 - pulseOffset, y: 215))
        p.addLine(to: CGPoint(x: 165 - pulseOffset, y: 215))
        p.addLine(to: CGPoint(x: 210, y: 150))
        p.addLine(to: CGPoint(x: 165 - pulseOffset, y: 72))
        p.closeSubpath()

        // Smile/line on the right (from SVG: a rounded rect from 241,188 to 356,218)
        let smileHeight: CGFloat = 30
        let smileY: CGFloat = 188 + (218 - 188 - smileHeight) / 2
        p.addRoundedRect(in: CGRect(x: 241, y: smileY, width: 115, height: smileHeight),
                        cornerSize: CGSize(width: 15, height: 15))

        return p.applying(t)
    }
}

/// Sitting Codex legs
struct CodexSittingLegsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        var p = Path()
        p.addRect(CGRect(x: -50, y: 245, width: 140, height: 45))
        p.addRect(CGRect(x: -50, y: 300, width: 140, height: 45))
        p.addRect(CGRect(x: 400, y: 245, width: 140, height: 45))
        p.addRect(CGRect(x: 400, y: 300, width: 140, height: 45))
        return p.applying(t)
    }
}

/// Sitting Codex body
struct CodexSittingBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        var p = Path()
        p.move(to: CGPoint(x: 45, y: 350))
        p.addLine(to: CGPoint(x: 45, y: 192))
        p.addLine(to: CGPoint(x: 0, y: 192))
        p.addLine(to: CGPoint(x: 0, y: 96))
        p.addLine(to: CGPoint(x: 45, y: 96))
        p.addLine(to: CGPoint(x: 45, y: 0))
        p.addLine(to: CGPoint(x: 445, y: 0))
        p.addLine(to: CGPoint(x: 445, y: 96))
        p.addLine(to: CGPoint(x: 490, y: 96))
        p.addLine(to: CGPoint(x: 490, y: 192))
        p.addLine(to: CGPoint(x: 445, y: 192))
        p.addLine(to: CGPoint(x: 445, y: 350))
        p.closeSubpath()
        return p.applying(t)
    }
}

/// Sitting Codex face — half-closed
struct CodexSittingFaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        var p = Path()
        // Squinted > chevron
        p.move(to: CGPoint(x: 145, y: 110))
        p.addLine(to: CGPoint(x: 185, y: 142))
        p.addLine(to: CGPoint(x: 145, y: 175))
        p.addLine(to: CGPoint(x: 160, y: 175))
        p.addLine(to: CGPoint(x: 195, y: 148))
        p.addLine(to: CGPoint(x: 160, y: 110))
        p.closeSubpath()
        // Thin smile
        p.addRoundedRect(in: CGRect(x: 250, y: 135, width: 95, height: 15),
                        cornerSize: CGSize(width: 7, height: 7))
        return p.applying(t)
    }
}
