import SwiftUI

struct MascotView: View {
    let agentType: AgentType
    let status: SessionStatus
    let size: CGFloat

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        ZStack {
            mascotShape
                .opacity(status == .idle ? 0.7 : 1.0)
                .scaleEffect(thinkingScale)
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
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            animationPhase = 1
        }
    }

    private var thinkingScale: CGFloat {
        status == .thinking ? 1.0 + animationPhase * 0.06 : 1.0
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

/// Clawd mascot — pixel-art Claude character.
/// SVG viewBox: 490x385. Body is #DA7758, eyes are black.
struct ClawdMascot: View {
    let status: SessionStatus
    let animationPhase: CGFloat

    private let bodyColor = Color(red: 0.855, green: 0.467, blue: 0.345) // #DA7758

    var body: some View {
        ZStack {
            // Body
            ClawdBodyShape()
                .fill(status == .error ? .red : bodyColor)

            // Eyes
            ClawdEyesShape(animationPhase: status == .thinking ? animationPhase : 0)
                .fill(.black)
        }
        .aspectRatio(490.0 / 385.0, contentMode: .fit)
    }
}

/// The Clawd body shape (the orange silhouette).
struct ClawdBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 490
        let sy = rect.height / 385
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        var p = Path()
        // Main body path from SVG
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

/// The Clawd eyes — two square eyes that blink when thinking.
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

        // Eye height squishes for blink effect
        let eyeHeight: CGFloat = 48.5 * (1.0 - animationPhase * 0.7)
        let eyeYOffset: CGFloat = (48.5 - eyeHeight) / 2

        var p = Path()
        // Left eye (89, 95) to (134.5, 143.5)
        p.addRect(CGRect(x: 89, y: 95 + eyeYOffset, width: 45.5, height: eyeHeight))
        // Right eye (355, 95) to (400.5, 143.5)
        p.addRect(CGRect(x: 355, y: 95 + eyeYOffset, width: 45.5, height: eyeHeight))

        return p.applying(t)
    }
}
