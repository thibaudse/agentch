import SwiftUI

struct IslandView: View {
    @ObservedObject var model: IslandViewModel
    let onClose: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        let geometry = model.geometry
        let width = geometry.effectiveWidth(interactive: model.interactive)
        let height = geometry.effectiveHeight(interactive: model.interactive)

        ZStack(alignment: .bottom) {
            Color.black

            VStack(spacing: 8) {
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

                    if !model.message.isEmpty {
                        Text(model.message)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

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

                if model.interactive {
                    HStack(spacing: 8) {
                        TextField("Type your response...", text: $model.inputText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white)
                            .tint(.white)
                            .focused($isInputFocused)
                            .onSubmit { model.submit() }

                        Button(action: { model.submit() }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(
                                    model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? .white.opacity(0.2)
                                        : .white.opacity(0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .frame(width: width, height: height)
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
            x: model.expanded ? 1 : geometry.collapsedScaleX(interactive: model.interactive),
            y: model.expanded ? 1 : geometry.collapsedScaleY(interactive: model.interactive),
            anchor: .top
        )
        .onExitCommand { onClose() }
        .onChange(of: model.expanded) { _, expanded in
            if expanded && model.interactive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isInputFocused = true
                }
            }
        }
    }
}
