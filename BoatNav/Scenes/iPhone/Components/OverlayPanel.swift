import SwiftUI
import Combine

enum PanelDetent: Equatable {
    case collapsed
    case half
    case expanded
}

enum ActivePanel: Equatable {
    case none
    case navigation
    case settings
    case speedDetail
    case boatProfile
    case paywall
    case locationSharing
}

struct OverlayPanel<Content: View>: View {
    @Binding var detent: PanelDetent
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    @GestureState private var dragOffset: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var detentBeforeKeyboard: PanelDetent?

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height + geometry.safeAreaInsets.bottom
            let targetHeight = height(for: detent, in: screenHeight)
            let currentHeight = max(0, targetHeight - dragOffset)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    // Drag handle + sticky close button
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(.white.opacity(0.25))
                            .frame(width: 40, height: 5)
                        Spacer()
                    }
                    .overlay(alignment: .trailing) {
                        Button {
                            withAnimation(Design.Animation.panel) {
                                onDismiss()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(.quaternary, in: Circle())
                        }
                        .padding(.trailing, Design.Spacing.xl)
                    }
                    .padding(.top, Design.Spacing.md)
                    .padding(.bottom, Design.Spacing.sm)

                    // Content
                    ScrollView {
                        content()
                            .padding(.horizontal, 20)
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .frame(height: currentHeight)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Design.Corner.large, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: Design.Corner.large, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                )
                .shadow(color: .black.opacity(0.20), radius: 24, y: -6)
                .clipShape(RoundedRectangle(cornerRadius: Design.Corner.large, style: .continuous))
                .simultaneousGesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            handleDragEnd(translation: value.translation.height, velocity: value.predictedEndTranslation.height, maxHeight: screenHeight)
                        }
                )

                // Keyboard spacer: pushes panel above keyboard
                if keyboardHeight > 0 {
                    Color.clear
                        .frame(height: keyboardHeight - geometry.safeAreaInsets.bottom)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onReceive(keyboardPublisher) { height in
            withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                if height > 0 {
                    keyboardHeight = height
                    if detent != .expanded {
                        detentBeforeKeyboard = detent
                        detent = .expanded
                    }
                } else {
                    keyboardHeight = 0
                    if let previous = detentBeforeKeyboard {
                        detent = previous
                        detentBeforeKeyboard = nil
                    }
                }
            }
        }
    }

    // dragHandle is now integrated in the main body with sticky close button

    private func height(for detent: PanelDetent, in maxHeight: CGFloat) -> CGFloat {
        switch detent {
        case .collapsed: return 80
        case .half: return maxHeight * 0.75
        case .expanded: return maxHeight * 0.85
        }
    }

    private func handleDragEnd(translation: CGFloat, velocity: CGFloat, maxHeight: CGFloat) {
        let currentHeight = height(for: detent, in: maxHeight) - translation

        // If dragged down significantly or with high velocity, dismiss or collapse
        if velocity > 800 || (translation > 100 && detent == .collapsed) {
            withAnimation(Design.Animation.panel) {
                onDismiss()
            }
            return
        }

        // Snap to nearest detent
        let collapsedH = height(for: .collapsed, in: maxHeight)
        let halfH = height(for: .half, in: maxHeight)
        let expandedH = height(for: .expanded, in: maxHeight)

        let distances: [(PanelDetent, CGFloat)] = [
            (.collapsed, abs(currentHeight - collapsedH)),
            (.half, abs(currentHeight - halfH)),
            (.expanded, abs(currentHeight - expandedH))
        ]

        if let nearest = distances.min(by: { $0.1 < $1.1 }) {
            withAnimation(Design.Animation.panel) {
                detent = nearest.0
            }
        }
    }

    private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        return willShow.merge(with: willHide)
            .eraseToAnyPublisher()
    }
}
