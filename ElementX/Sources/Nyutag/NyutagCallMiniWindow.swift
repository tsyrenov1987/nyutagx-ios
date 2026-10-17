//
// Нютаг — свёрнутый звонок: плавающее мини-окно поверх приложения вместо системного PiP.
// Перетаскивается пальцем, липнет к краю; тап — вернуться в звонок; кнопки — микрофон и завершить.
// Живёт в своём UIWindow, поэтому видно и поверх листов («Настройки» и т. п.).
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

    /// Вид внутри показанного мини-окна: из него iOS разворачивает системный PiP, пока звонок свёрнут.
    private(set) weak var pictureInPictureAnchor: UIView?
    var onPictureInPictureAnchorChange: () -> Void = { }

    fileprivate func setPictureInPictureAnchor(_ view: UIView?) {
        pictureInPictureAnchor = view
        onPictureInPictureAnchorChange()
    }

    init(title: String) {
        self.title = title
    }
}

struct NyutagCallMiniWindow: View {
    @ObservedObject var model: NyutagCallMiniWindowModel

    var body: some View {
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
                        SwiftUI.TimelineView(.periodic(from: model.startedAt, by: 1)) { context in
                            Text(Self.duration(since: model.startedAt, now: context.date))
                                .font(.compound.bodyXS)
                                .foregroundStyle(.white.opacity(0.7))
                                .monospacedDigit()
                        }
                    }
                    // Постоянная ширина: окно-хозяин не меняет размер, когда таймер переходит на минуты и часы.
                    .frame(width: 120, alignment: .leading)
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
        .background(PictureInPictureAnchor(model: model))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        // Поле под тень: окно-хозяин обрезает всё, что за его краями.
        .padding(NyutagFloatingWindowHost.shadowInset)
        .environment(\.colorScheme, .dark)
    }

    fileprivate static func duration(since start: Date, now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let hours = total / 3600, minutes = total % 3600 / 60, seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }
}

/// Голосовой звонок в системном PiP, когда приложение свёрнуто: имя, таймер, микрофон — как плашка звонка вне приложения.
struct NyutagCallPictureInPictureContent: View {
    @ObservedObject var model: NyutagCallMiniWindowModel

    var body: some View {
        VStack(spacing: 6) {
            Image(systemSymbol: model.isMuted ? .micSlashFill : .phoneFill)
                .font(.system(size: 34))
                .foregroundStyle(model.isMuted ? Color.red : Color.green)
            Text(model.title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            SwiftUI.TimelineView(.periodic(from: model.startedAt, by: 1)) { context in
                Text(NyutagCallMiniWindow.duration(since: model.startedAt, now: context.date))
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.13, green: 0.15, blue: 0.18))
    }
}

/// Сообщает модели, что мини-окно на экране (вид попал в окно) или убрано.
private struct PictureInPictureAnchor: UIViewRepresentable {
    let model: NyutagCallMiniWindowModel

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.onWindowChange = { [weak model] view in model?.setPictureInPictureAnchor(view.window == nil ? nil : view) }
        return view
    }

    func updateUIView(_ uiView: AnchorView, context: Context) { }

    final class AnchorView: UIView {
        var onWindowChange: (AnchorView) -> Void = { _ in }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange(self)
        }
    }
}

/// Держит мини-окно звонка в отдельном UIWindow над всем приложением — над листами («Настройки», сведения о чате)
/// и полноэкранными экранами, как плашку звонка в Telegram. Раньше окно рисовалось поверх вкладок и пряталось под любым листом.
/// Окно размером ровно с плашку: касания мимо неё уходят приложению. Перетаскивается пальцем и липнет к краю.
final class NyutagFloatingWindowHost: NSObject {
    static let shadowInset = 12.0
    private static let margin = 4.0

    /// Положение относительно правого верхнего угла безопасной зоны; хранится между звонками.
    private static let offsetXKey = "nyutag.callMiniWindow.offset.x"
    private static let offsetYKey = "nyutag.callMiniWindow.offset.y"

    /// Окно блокировки приложения: пока оно видно, мини-окно прячем — иначе имя собеседника и кнопки звонка видны поверх экрана с кодом.
    static weak var coveringWindow: UIWindow?

    private var window: UIWindow?

    var isShown: Bool { window != nil }

    override init() {
        super.init()
        for name in [UIWindow.didBecomeVisibleNotification, UIWindow.didBecomeHiddenNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(coveringWindowDidChange), name: name, object: nil)
        }
    }

    func show(_ view: AnyView) {
        hide()
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            MXLog.warning("Nyutag call mini window: no window scene to show it in")
            return
        }

        let hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .clear
        let size = hostingController.sizeThatFits(in: CGSize(width: 1000, height: 1000))

        let window = UIWindow(windowScene: scene)
        // Над окном приложения, но под системными алертами.
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear
        window.rootViewController = hostingController
        let area = Self.allowedArea(in: scene)
        let defaults = UserDefaults.standard
        let center = CGPoint(x: area.maxX - size.width / 2 + defaults.double(forKey: Self.offsetXKey),
                             y: area.minY + size.height / 2 + defaults.double(forKey: Self.offsetYKey))
        window.frame = CGRect(origin: .zero, size: size)
        window.center = Self.clamp(center, size: size, in: area)
        hostingController.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
        window.isHidden = Self.coveringWindow?.isHidden == false
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        // Снимаем содержимое явно: якорь PiP узнаёт, что мини-окна больше нет.
        window?.rootViewController = nil
        window = nil
    }

    @objc private func coveringWindowDidChange(_ notification: Notification) {
        guard let window, let coveringWindow = Self.coveringWindow, notification.object as? UIWindow === coveringWindow else { return }
        window.isHidden = !coveringWindow.isHidden
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let window, let scene = window.windowScene else { return }
        let translation = recognizer.translation(in: nil)
        recognizer.setTranslation(.zero, in: nil)
        window.center = CGPoint(x: window.center.x + translation.x, y: window.center.y + translation.y)

        guard recognizer.state == .ended || recognizer.state == .cancelled else { return }
        let area = Self.allowedArea(in: scene)
        let size = window.bounds.size
        var target = Self.clamp(window.center, size: size, in: area)
        // Липнем к ближнему краю по горизонтали, по вертикали остаёмся где отпустили.
        target.x = target.x < area.midX ? area.minX + size.width / 2 : area.maxX - size.width / 2
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            window.center = target
        }
        UserDefaults.standard.set(target.x - (area.maxX - size.width / 2), forKey: Self.offsetXKey)
        UserDefaults.standard.set(target.y - (area.minY + size.height / 2), forKey: Self.offsetYKey)
    }

    /// Безопасная зона экрана (без чёлки и полоски «домой»); поле под тень может заходить за неё.
    private static func allowedArea(in scene: UIWindowScene) -> CGRect {
        let insets = scene.windows.first { $0.isKeyWindow }?.safeAreaInsets ?? scene.windows.first?.safeAreaInsets ?? .zero
        return scene.coordinateSpace.bounds
            .inset(by: insets)
            .insetBy(dx: margin - shadowInset, dy: margin - shadowInset)
    }

    private static func clamp(_ point: CGPoint, size: CGSize, in area: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, area.minX + size.width / 2), area.maxX - size.width / 2),
                y: min(max(point.y, area.minY + size.height / 2), area.maxY - size.height / 2))
    }
}

struct NyutagCallMiniWindow_Previews: PreviewProvider {
    static var previews: some View {
        NyutagCallMiniWindow(model: .init(title: "Чингис"))
            .background(Color.gray)
    }
}
