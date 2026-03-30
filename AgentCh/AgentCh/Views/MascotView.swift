import SwiftUI

struct MascotView: View {
    let agentType: AgentType
    let status: SessionStatus
    let size: CGFloat

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        ZStack {
            mascotShape
                .opacity(status == .idle ? 0.65 : 1.0)
                .scaleEffect(thinkingScale)
                .offset(y: thinkingBounce)
        }
        .frame(width: size, height: size)
        .onAppear {
            if status == .thinking {
                startThinkingAnimation()
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
            Image(systemName: "terminal.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.green)
                .padding(4)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.gray)
                .padding(4)
        }
    }
}

/// Pulsing status indicator dot.
struct StatusDot: View {
    let status: SessionStatus
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .scaleEffect(status == .thinking && pulse ? 1.4 : 1.0)
            .opacity(status == .thinking && pulse ? 0.6 : 1.0)
            .animation(
                status == .thinking
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear {
                if status == .thinking { pulse = true }
            }
            .onChange(of: status) { _, newStatus in
                pulse = newStatus == .thinking
            }
    }

    private var color: Color {
        switch status {
        case .thinking: return .green
        case .idle: return .gray
        case .error: return .red
        }
    }
}

/// Clawd mascot — pixel-art Claude character.
struct ClawdMascot: View {
    let status: SessionStatus
    let animationPhase: CGFloat

    private let bodyColor = Color(red: 0.855, green: 0.467, blue: 0.345)

    var body: some View {
        ZStack {
            ClawdBodyShape()
                .fill(status == .error ? .red : bodyColor)

            ClawdEyesShape(animationPhase: status == .thinking ? animationPhase : 0)
                .fill(.black)
        }
        .aspectRatio(490.0 / 385.0, contentMode: .fit)
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

        let eyeHeight: CGFloat = 48.5 * (1.0 - animationPhase * 0.7)
        let eyeYOffset: CGFloat = (48.5 - eyeHeight) / 2

        var p = Path()
        p.addRect(CGRect(x: 89, y: 95 + eyeYOffset, width: 45.5, height: eyeHeight))
        p.addRect(CGRect(x: 355, y: 95 + eyeYOffset, width: 45.5, height: eyeHeight))
        return p.applying(t)
    }
}
