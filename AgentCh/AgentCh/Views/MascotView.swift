import SwiftUI

struct MascotView: View {
    let agentType: AgentType
    let status: SessionStatus
    let size: CGFloat

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        ZStack {
            mascotShape
                .opacity(status == .idle ? 0.6 : 1.0)
                .scaleEffect(thinkingScale)
                .foregroundStyle(mascotColor)
        }
        .frame(width: size, height: size)
        .onAppear {
            if status == .thinking {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    animationPhase = 1
                }
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus == .thinking {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    animationPhase = 1
                }
            } else {
                withAnimation(.spring(duration: 0.3)) {
                    animationPhase = 0
                }
            }
        }
    }

    private var thinkingScale: CGFloat {
        status == .thinking ? 1.0 + animationPhase * 0.1 : 1.0
    }

    private var mascotColor: Color {
        switch status {
        case .idle: return agentBaseColor
        case .thinking: return agentBaseColor
        case .error: return .red
        }
    }

    private var agentBaseColor: Color {
        switch agentType {
        case .claude: return .orange
        case .codex: return .green
        case .unknown: return .gray
        }
    }

    @ViewBuilder
    private var mascotShape: some View {
        switch agentType {
        case .claude:
            ClaudeMascotShape(status: status, animationPhase: animationPhase)
        case .codex:
            Image(systemName: "terminal.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(4)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(4)
        }
    }
}

struct ClaudeMascotShape: View {
    let status: SessionStatus
    let animationPhase: CGFloat

    private let armCount = 6
    /// Fraction of the canvas radius used for arm length
    private let armLengthRatio: CGFloat = 0.42
    /// Fraction of the canvas radius used for arm width
    private let armWidthRatio: CGFloat = 0.18
    /// Fraction of the canvas radius used for center circle
    private let centerRadiusRatio: CGFloat = 0.15

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2

            let armLength = radius * armLengthRatio
            let armWidth = armLength * armWidthRatio / armLengthRatio
            let centerRadius = radius * centerRadiusRatio

            // Rotation offset for thinking animation
            let rotationOffset = status == .thinking ? animationPhase * 0.15 : 0

            // Draw the 6 arms radiating from center
            for i in 0..<armCount {
                let baseAngle = (CGFloat(i) / CGFloat(armCount)) * 2 * .pi - .pi / 2
                let angle = baseAngle + rotationOffset

                // Each arm is drawn as a rounded rect centered at a point along the arm direction
                let armCenterDistance = radius * 0.38
                let armCenterX = center.x + cos(angle) * armCenterDistance
                let armCenterY = center.y + sin(angle) * armCenterDistance

                // Create a rounded rectangle for the arm, then rotate it to point outward
                let armRect = CGRect(
                    x: -armWidth / 2,
                    y: -armLength / 2,
                    width: armWidth,
                    height: armLength
                )
                let cornerRadius = armWidth / 2

                var armPath = Path(roundedRect: armRect, cornerRadius: cornerRadius)

                // Transform: rotate the arm to point along its angle, then translate to position
                // The arm is drawn vertically (along Y), so we rotate by (angle + pi/2) to align
                let rotation = CGAffineTransform(rotationAngle: angle + .pi / 2)
                let translation = CGAffineTransform(translationX: armCenterX, y: armCenterY)
                armPath = armPath.applying(rotation.concatenating(translation))

                context.fill(armPath, with: .foreground)
            }

            // Draw center circle with pulse effect when thinking
            let pulseScale: CGFloat = status == .thinking ? 1.0 + animationPhase * 0.15 : 1.0
            let effectiveCenterRadius = centerRadius * pulseScale

            let centerCircle = Path(ellipseIn: CGRect(
                x: center.x - effectiveCenterRadius,
                y: center.y - effectiveCenterRadius,
                width: effectiveCenterRadius * 2,
                height: effectiveCenterRadius * 2
            ))
            context.fill(centerCircle, with: .foreground)
        }
    }
}
