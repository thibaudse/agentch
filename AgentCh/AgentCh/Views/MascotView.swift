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
                .rotationEffect(.degrees(status == .thinking ? animationPhase * 8 : 0))
                .foregroundStyle(mascotColor)
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
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            animationPhase = 1
        }
    }

    private var thinkingScale: CGFloat {
        status == .thinking ? 1.0 + animationPhase * 0.08 : 1.0
    }

    private var mascotColor: Color {
        switch status {
        case .error: return .red
        default: return agentBaseColor
        }
    }

    private var agentBaseColor: Color {
        switch agentType {
        case .claude: return Color(red: 0.85, green: 0.45, blue: 0.25)
        case .codex: return .green
        case .unknown: return .gray
        }
    }

    @ViewBuilder
    private var mascotShape: some View {
        switch agentType {
        case .claude:
            ClaudeLogoShape()
                .aspectRatio(contentMode: .fit)
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

/// The official Claude AI spark logo as a SwiftUI Shape.
/// SVG path from Bootstrap Icons (16x16 viewBox).
struct ClaudeLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Original SVG viewBox is 16x16
        let scaleX = rect.width / 16
        let scaleY = rect.height / 16
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

        var path = Path()

        // Claude logo SVG path data (from Bootstrap Icons bi-claude, 16x16 viewBox)
        path.move(to: CGPoint(x: 3.127, y: 10.604))
        path.addLine(to: CGPoint(x: 6.262, y: 8.844))
        path.addLine(to: CGPoint(x: 6.315, y: 8.691))
        path.addLine(to: CGPoint(x: 6.262, y: 8.606))
        path.addLine(to: CGPoint(x: 6.11, y: 8.606))
        path.addLine(to: CGPoint(x: 5.585, y: 8.574))
        path.addLine(to: CGPoint(x: 3.794, y: 8.526))
        path.addLine(to: CGPoint(x: 2.24, y: 8.461))
        path.addLine(to: CGPoint(x: 0.735, y: 8.381))
        path.addLine(to: CGPoint(x: 0.355, y: 8.3))
        path.addLine(to: CGPoint(x: 0, y: 7.832))
        path.addLine(to: CGPoint(x: 0.036, y: 7.598))
        path.addLine(to: CGPoint(x: 0.356, y: 7.384))
        path.addLine(to: CGPoint(x: 0.811, y: 7.424))
        path.addLine(to: CGPoint(x: 1.82, y: 7.493))
        path.addLine(to: CGPoint(x: 3.333, y: 7.598))
        path.addLine(to: CGPoint(x: 4.43, y: 7.662))
        path.addLine(to: CGPoint(x: 6.056, y: 7.832))
        path.addLine(to: CGPoint(x: 6.315, y: 7.832))
        path.addLine(to: CGPoint(x: 6.351, y: 7.727))
        path.addLine(to: CGPoint(x: 6.262, y: 7.662))
        path.addLine(to: CGPoint(x: 6.194, y: 7.598))
        path.addLine(to: CGPoint(x: 4.628, y: 6.536))
        path.addLine(to: CGPoint(x: 2.933, y: 5.415))
        path.addLine(to: CGPoint(x: 2.046, y: 4.769))
        path.addLine(to: CGPoint(x: 1.566, y: 4.442))
        path.addLine(to: CGPoint(x: 1.323, y: 4.136))
        path.addLine(to: CGPoint(x: 1.219, y: 3.466))
        path.addLine(to: CGPoint(x: 1.654, y: 2.986))
        path.addLine(to: CGPoint(x: 2.239, y: 3.026))
        path.addLine(to: CGPoint(x: 2.389, y: 3.066))
        path.addLine(to: CGPoint(x: 2.982, y: 3.522))
        path.addLine(to: CGPoint(x: 4.249, y: 4.503))
        path.addLine(to: CGPoint(x: 5.903, y: 5.721))
        path.addLine(to: CGPoint(x: 6.145, y: 5.923))
        path.addLine(to: CGPoint(x: 6.242, y: 5.855))
        path.addLine(to: CGPoint(x: 6.254, y: 5.806))
        path.addLine(to: CGPoint(x: 6.145, y: 5.625))
        path.addLine(to: CGPoint(x: 5.245, y: 3.999))
        path.addLine(to: CGPoint(x: 4.285, y: 2.344))
        path.addLine(to: CGPoint(x: 3.857, y: 1.658))
        path.addLine(to: CGPoint(x: 3.744, y: 1.247))
        path.addCurve(to: CGPoint(x: 3.676, y: 0.763),
                      control1: CGPoint(x: 3.714, y: 1.077),
                      control2: CGPoint(x: 3.676, y: 0.933))
        path.addLine(to: CGPoint(x: 4.172, y: 0.089))
        path.addLine(to: CGPoint(x: 4.446, y: 0))
        path.addLine(to: CGPoint(x: 5.108, y: 0.089))
        path.addLine(to: CGPoint(x: 5.387, y: 0.331))
        path.addLine(to: CGPoint(x: 5.798, y: 1.271))
        path.addLine(to: CGPoint(x: 6.464, y: 2.751))
        path.addLine(to: CGPoint(x: 7.497, y: 4.765))
        path.addLine(to: CGPoint(x: 7.799, y: 5.362))
        path.addLine(to: CGPoint(x: 7.961, y: 5.915))
        path.addLine(to: CGPoint(x: 8.021, y: 6.085))
        path.addLine(to: CGPoint(x: 8.126, y: 6.085))
        path.addLine(to: CGPoint(x: 8.126, y: 5.988))
        path.addLine(to: CGPoint(x: 8.211, y: 4.854))
        path.addLine(to: CGPoint(x: 8.368, y: 3.462))
        path.addLine(to: CGPoint(x: 8.522, y: 1.67))
        path.addLine(to: CGPoint(x: 8.574, y: 1.166))
        path.addLine(to: CGPoint(x: 8.824, y: 0.561))
        path.addLine(to: CGPoint(x: 9.321, y: 0.234))
        path.addLine(to: CGPoint(x: 9.708, y: 0.42))
        path.addLine(to: CGPoint(x: 10.027, y: 0.876))
        path.addLine(to: CGPoint(x: 9.982, y: 1.17))
        path.addLine(to: CGPoint(x: 9.792, y: 2.4))
        path.addLine(to: CGPoint(x: 9.422, y: 4.33))
        path.addLine(to: CGPoint(x: 9.179, y: 5.62))
        path.addLine(to: CGPoint(x: 9.321, y: 5.62))
        path.addLine(to: CGPoint(x: 9.482, y: 5.46))
        path.addLine(to: CGPoint(x: 10.136, y: 4.592))
        path.addLine(to: CGPoint(x: 11.233, y: 3.22))
        path.addLine(to: CGPoint(x: 11.717, y: 2.675))
        path.addLine(to: CGPoint(x: 12.282, y: 2.074))
        path.addLine(to: CGPoint(x: 12.645, y: 1.787))
        path.addLine(to: CGPoint(x: 13.331, y: 1.787))
        path.addLine(to: CGPoint(x: 13.836, y: 2.538))
        path.addLine(to: CGPoint(x: 13.61, y: 3.313))
        path.addLine(to: CGPoint(x: 12.903, y: 4.208))
        path.addLine(to: CGPoint(x: 12.318, y: 4.967))
        path.addLine(to: CGPoint(x: 11.479, y: 6.097))
        path.addLine(to: CGPoint(x: 10.955, y: 7.001))
        path.addLine(to: CGPoint(x: 11.003, y: 7.073))
        path.addLine(to: CGPoint(x: 11.128, y: 7.061))
        path.addLine(to: CGPoint(x: 13.025, y: 6.658))
        path.addLine(to: CGPoint(x: 14.049, y: 6.472))
        path.addLine(to: CGPoint(x: 15.272, y: 6.262))
        path.addLine(to: CGPoint(x: 15.825, y: 6.52))
        path.addLine(to: CGPoint(x: 15.885, y: 6.783))
        path.addLine(to: CGPoint(x: 15.667, y: 7.319))
        path.addLine(to: CGPoint(x: 14.36, y: 7.642))
        path.addLine(to: CGPoint(x: 12.827, y: 7.949))
        path.addLine(to: CGPoint(x: 10.543, y: 8.489))
        path.addLine(to: CGPoint(x: 10.515, y: 8.509))
        path.addLine(to: CGPoint(x: 10.547, y: 8.549))
        path.addLine(to: CGPoint(x: 11.576, y: 8.647))
        path.addLine(to: CGPoint(x: 12.016, y: 8.671))
        path.addLine(to: CGPoint(x: 12.016, y: 8.695))
        path.addLine(to: CGPoint(x: 13.093, y: 8.695))
        path.addLine(to: CGPoint(x: 15.098, y: 8.845))
        path.addLine(to: CGPoint(x: 15.623, y: 9.191))
        path.addLine(to: CGPoint(x: 15.938, y: 9.615))
        path.addLine(to: CGPoint(x: 15.885, y: 9.938))
        path.addLine(to: CGPoint(x: 15.078, y: 10.349))
        path.addLine(to: CGPoint(x: 11.447, y: 9.486))
        path.addLine(to: CGPoint(x: 10.575, y: 9.268))
        path.addLine(to: CGPoint(x: 10.455, y: 9.268))
        path.addLine(to: CGPoint(x: 10.455, y: 9.341))
        path.addLine(to: CGPoint(x: 11.181, y: 10.051))
        path.addLine(to: CGPoint(x: 12.512, y: 11.253))
        path.addLine(to: CGPoint(x: 14.179, y: 12.803))
        path.addLine(to: CGPoint(x: 14.263, y: 13.186))
        path.addLine(to: CGPoint(x: 14.049, y: 13.488))
        path.addLine(to: CGPoint(x: 13.823, y: 13.456))
        path.addLine(to: CGPoint(x: 12.359, y: 12.355))
        path.addLine(to: CGPoint(x: 11.794, y: 11.858))
        path.addLine(to: CGPoint(x: 10.514, y: 10.781))
        path.addLine(to: CGPoint(x: 10.43, y: 10.781))
        path.addLine(to: CGPoint(x: 10.43, y: 10.894))
        path.addLine(to: CGPoint(x: 10.725, y: 11.326))
        path.addLine(to: CGPoint(x: 12.282, y: 13.666))
        path.addLine(to: CGPoint(x: 12.362, y: 14.384))
        path.addLine(to: CGPoint(x: 12.25, y: 14.618))
        path.addLine(to: CGPoint(x: 11.846, y: 14.759))
        path.addLine(to: CGPoint(x: 11.402, y: 14.679))
        path.addLine(to: CGPoint(x: 10.491, y: 13.399))
        path.addLine(to: CGPoint(x: 9.551, y: 11.959))
        path.addLine(to: CGPoint(x: 8.792, y: 10.668))
        path.addLine(to: CGPoint(x: 8.699, y: 10.721))
        path.addLine(to: CGPoint(x: 8.251, y: 15.542))
        path.addLine(to: CGPoint(x: 8.041, y: 15.788))
        path.addLine(to: CGPoint(x: 7.557, y: 15.974))
        path.addLine(to: CGPoint(x: 7.154, y: 15.667))
        path.addLine(to: CGPoint(x: 6.94, y: 15.171))
        path.addLine(to: CGPoint(x: 7.154, y: 14.191))
        path.addLine(to: CGPoint(x: 7.412, y: 12.911))
        path.addLine(to: CGPoint(x: 7.622, y: 11.895))
        path.addLine(to: CGPoint(x: 7.812, y: 10.632))
        path.addLine(to: CGPoint(x: 7.924, y: 10.212))
        path.addLine(to: CGPoint(x: 7.916, y: 10.184))
        path.addLine(to: CGPoint(x: 7.824, y: 10.196))
        path.addLine(to: CGPoint(x: 6.871, y: 11.503))
        path.addLine(to: CGPoint(x: 5.423, y: 13.46))
        path.addLine(to: CGPoint(x: 4.277, y: 14.687))
        path.addLine(to: CGPoint(x: 4.003, y: 14.796))
        path.addLine(to: CGPoint(x: 3.526, y: 14.549))
        path.addLine(to: CGPoint(x: 3.571, y: 14.109))
        path.addLine(to: CGPoint(x: 3.837, y: 13.719))
        path.addLine(to: CGPoint(x: 5.423, y: 11.701))
        path.addLine(to: CGPoint(x: 6.379, y: 10.451))
        path.addLine(to: CGPoint(x: 6.996, y: 9.728))
        path.addLine(to: CGPoint(x: 6.992, y: 9.623))
        path.addLine(to: CGPoint(x: 6.956, y: 9.623))
        path.addLine(to: CGPoint(x: 2.744, y: 12.359))
        path.addLine(to: CGPoint(x: 1.994, y: 12.455))
        path.addLine(to: CGPoint(x: 1.67, y: 12.153))
        path.addLine(to: CGPoint(x: 1.71, y: 11.657))
        path.addLine(to: CGPoint(x: 1.864, y: 11.495))
        path.addLine(to: CGPoint(x: 3.131, y: 10.624))
        path.closeSubpath()

        return path.applying(transform)
    }
}
