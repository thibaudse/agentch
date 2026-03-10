import SwiftUI

struct IslandView: View {
    @ObservedObject var model: IslandViewModel
    let onClose: () -> Void

    var body: some View {
        let geometry = model.geometry

        ZStack(alignment: .bottom) {
            Color.black

            HStack(spacing: 10) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green.opacity(0.7), radius: 5)

                if !model.agentName.isEmpty {
                    Text(model.agentName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text(model.message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .frame(width: geometry.expandedWidth, height: geometry.expandedHeight)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: geometry.hasNotch ? 8 : 12,
                    bottomLeading: 18,
                    bottomTrailing: 18,
                    topTrailing: geometry.hasNotch ? 8 : 12
                ),
                style: .continuous
            )
        )
        .scaleEffect(
            x: model.expanded ? 1 : geometry.collapsedScaleX,
            y: model.expanded ? 1 : geometry.collapsedScaleY,
            anchor: .top
        )
    }
}
