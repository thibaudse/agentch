import SwiftUI

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
}

struct ParticleTrailView: View {
    @ObservedObject var pillPosition: PillPosition
    @State private var particles: [Particle] = []
    @State private var timer: Timer?

    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let rect = CGRect(
                    x: particle.position.x - 2,
                    y: particle.position.y - 2,
                    width: 4 * particle.scale,
                    height: 4 * particle.scale
                )
                context.opacity = particle.opacity
                context.fill(
                    Circle().path(in: rect),
                    with: .color(.primary.opacity(0.3))
                )
            }
        }
        .allowsHitTesting(false)
        .onChange(of: pillPosition.isDragging) { _, dragging in
            if dragging {
                startEmitting()
            } else {
                stopEmitting()
            }
        }
    }

    private func startEmitting() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            Task { @MainActor in
                // Add particle at current pill position
                let screen = pillPosition.screen
                let x = screen.frame.width / 2 + pillPosition.offset.width
                let y = pillPosition.topPadding + pillPosition.offset.height
                particles.append(Particle(position: CGPoint(x: x, y: y)))

                // Fade and remove old particles
                withAnimation(.linear(duration: 0.4)) {
                    particles = particles.compactMap { p in
                        var p = p
                        p.opacity -= 0.15
                        p.scale *= 0.85
                        return p.opacity > 0.05 ? p : nil
                    }
                }
            }
        }
    }

    private func stopEmitting() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.5)) {
            particles = []
        }
    }
}
