//
// Нютаг — свёрнутый звонок: плавающее мини-окно поверх приложения вместо системного PiP.
// Перетаскивается пальцем, липнет к краю; тап — вернуться в звонок; кнопки — микрофон и завершить.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import SFSafeSymbols
import SwiftUI

/// Состояние свёрнутого звонка. Живёт в модели экрана звонка, окно только отображает и дёргает действия.
final class NyutagCallMiniWindowModel: ObservableObject {
    @Published var title: String
    @Published var isMuted = false
    let startedAt = Date()

    var onRestore: () -> Void = { }
    var onToggleMute: () -> Void = { }
    var onEnd: () -> Void = { }

    init(title: String) {
        self.title = title
    }
}

struct NyutagCallMiniWindow: View {
    @ObservedObject var model: NyutagCallMiniWindowModel

    /// Положение окна относительно правого верхнего угла; хранится между звонками.
    @AppStorage("nyutag.callMiniWindow.offset.x") private var storedX = 0.0
    @AppStorage("nyutag.callMiniWindow.offset.y") private var storedY = 0.0
    @State private var dragTranslation: CGSize = .zero

    private let margin = 12.0

    var body: some View {
        GeometryReader { geometry in
            window
                .fixedSize()
                .background(SizeReader { windowSize = $0 })
                .position(position(in: geometry.size))
                .gesture(drag(in: geometry.size))
                .animation(.spring(duration: 0.3), value: storedX)
                .animation(.spring(duration: 0.3), value: storedY)
        }
        .ignoresSafeArea(.keyboard)
    }

    @State private var windowSize = CGSize(width: 200, height: 64)

    private var window: some View {
        HStack(spacing: 10) {
            Button(action: model.onRestore) {
                HStack(spacing: 8) {
                    Image(systemSymbol: .phoneFill)
                        .font(.compound.bodyLG)
                        .foregroundStyle(Color.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.title)
                            .font(.compound.bodyMDSemibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: 120, alignment: .leading)
                        SwiftUI.TimelineView(.periodic(from: model.startedAt, by: 1)) { context in
                            Text(Self.duration(since: model.startedAt, now: context.date))
                                .font(.compound.bodyXS)
                                .foregroundStyle(.white.opacity(0.7))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NyutagL10n.callReturn)

            Button(action: model.onToggleMute) {
                Image(systemSymbol: model.isMuted ? .micSlashFill : .micFill)
                    .font(.compound.bodyLG)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(model.isMuted ? 0.35 : 0.15), in: Circle())
            }
            .accessibilityLabel(model.isMuted ? L10n.commonUnmute : L10n.commonMute)

            Button(action: model.onEnd) {
                Image(systemSymbol: .phoneDownFill)
                    .font(.compound.bodyLG)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.red, in: Circle())
            }
            .accessibilityLabel(NyutagL10n.callEnd)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 0.13, green: 0.15, blue: 0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }

    // MARK: Положение и перетаскивание

    private func position(in container: CGSize) -> CGPoint {
        let base = CGPoint(x: container.width - margin - windowSize.width / 2 + storedX,
                           y: margin + windowSize.height / 2 + storedY)
        return clamp(CGPoint(x: base.x + dragTranslation.width, y: base.y + dragTranslation.height), in: container)
    }

    private func clamp(_ point: CGPoint, in container: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, margin + windowSize.width / 2), container.width - margin - windowSize.width / 2),
                y: min(max(point.y, margin + windowSize.height / 2), container.height - margin - windowSize.height / 2))
    }

    private func drag(in container: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { dragTranslation = $0.translation }
            .onEnded { value in
                let dropped = clamp(CGPoint(x: container.width - margin - windowSize.width / 2 + storedX + value.translation.width,
                                            y: margin + windowSize.height / 2 + storedY + value.translation.height),
                                    in: container)
                // Липнем к ближнему краю по горизонтали, по вертикали остаёмся где отпустили.
                let snappedX = dropped.x < container.width / 2 ? margin + windowSize.width / 2 : container.width - margin - windowSize.width / 2
                dragTranslation = .zero
                storedX = snappedX - (container.width - margin - windowSize.width / 2)
                storedY = dropped.y - (margin + windowSize.height / 2)
            }
    }

    private static func duration(since start: Date, now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let hours = total / 3600, minutes = total % 3600 / 60, seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }
}

/// Сообщает фактический размер содержимого, чтобы окно не вылезало за экран.
private struct SizeReader: View {
    let onChange: (CGSize) -> Void

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { onChange(geometry.size) }
                .onChange(of: geometry.size) { _, size in onChange(size) }
        }
    }
}

struct NyutagCallMiniWindow_Previews: PreviewProvider {
    static var previews: some View {
        NyutagCallMiniWindow(model: .init(title: "Чингис"))
            .background(Color.gray)
    }
}
