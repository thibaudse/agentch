import SwiftUI

struct MascotView: View {
    let agentType: AgentType
    let status: SessionStatus
    let size: CGFloat

    @State private var animationPhase: CGFloat = 0

    private let bubbleOverflow: CGFloat = 6

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mascotShape
                .opacity(status == .idle ? 0.5 : 1.0)
                .scaleEffect(thinkingScale)
                .offset(y: thinkingBounce)
                .rotationEffect(status == .waiting ? .degrees(90) : .degrees(0), anchor: .center)
                .offset(y: status == .waiting ? size * 0.15 : 0)
                .padding(bubbleOverflow)

            if status == .thinking {
                ThinkingBubble()
                    .offset(x: size * 0.35)
                    .transition(.scale(scale: 0, anchor: .bottomLeading).combined(with: .opacity))
            }

            if status == .waiting {
                SleepingZzz()
                    .offset(x: size * 0.3, y: -size * 0.05)
                    .transition(.scale(scale: 0, anchor: .bottomLeading).combined(with: .opacity))
            }
        }
        .frame(width: size + bubbleOverflow * 2, height: size + bubbleOverflow * 2)
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

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(.system(size: CGFloat(4 + i), weight: .bold, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.7 - Double(i) * 0.15))
                    .offset(
                        x: CGFloat(i) * 3,
                        y: -CGFloat(i) * 4 - phase * 2
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

/// Pulsing status indicator dot.
struct StatusDot: View {
    let status: SessionStatus
    @State private var pulse = false

    private var shouldPulse: Bool {
        status == .thinking || status == .waiting
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .scaleEffect(shouldPulse && pulse ? 1.4 : 1.0)
            .opacity(shouldPulse && pulse ? 0.6 : 1.0)
            .animation(
                shouldPulse
                    ? .easeInOut(duration: status == .waiting ? 1.2 : 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
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

            ClawdEyesShape(animationPhase: eyePhase)
                .fill(.black)
        }
        .aspectRatio(490.0 / 385.0, contentMode: .fit)
    }

    /// Thinking: squint (blink). Waiting: wide open (negative phase = taller eyes). Idle/error: normal.
    private var eyePhase: CGFloat {
        switch status {
        case .thinking: return animationPhase
        case .waiting: return -0.3
        case .idle, .error: return 0
        }
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
