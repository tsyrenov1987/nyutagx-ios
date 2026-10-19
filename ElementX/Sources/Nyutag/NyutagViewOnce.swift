//
// Нютаг (форк Element X iOS) — исчезающее фото: один просмотр, как в Telegram.
// Метка лежит в content события картинки (формат общий с Android): `{"chat.nyutag.view_once": true}`.
// Получатель видит заглушку, открывает фото один раз и затем удаляет событие (redact).
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import MatrixRustSDK
import SwiftUI

nonisolated enum NyutagViewOnce {
    static let key = "chat.nyutag.view_once"
    static let extraContentJSON = #"{"chat.nyutag.view_once":true}"#

    /// `originalJSON` — расшифрованное событие из отладочных данных SDK; у локального эха его ещё нет.
    static func isMarked(originalJSON: String?) -> Bool {
        guard let data = originalJSON?.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = event["content"] as? [String: Any] else {
            return false
        }
        return (content[key] as? Bool) == true
    }
}

/// Открытые фото: пока удаление не дошло до сервера, второй раз не откроются, даже если ячейку пересоздали.
/// Event ID пишется на диск в момент открытия — переживает убийство приложения во время просмотра.
@MainActor
enum NyutagViewOnceOpened {
    private static let defaultsKey = "nyutag_view_once_opened"
    private(set) static var itemIDs = Set<TimelineItemIdentifier.UniqueID>()

    static func markOpened(_ itemID: TimelineItemIdentifier, defaults: UserDefaults = .standard) {
        itemIDs.insert(itemID.uniqueID)
        guard let eventID = itemID.eventID else { return }
        defaults.set(openedEventIDs(defaults: defaults) + [eventID], forKey: defaultsKey)
    }

    static func wasOpened(_ itemID: TimelineItemIdentifier, defaults: UserDefaults = .standard) -> Bool {
        itemIDs.contains(itemID.uniqueID) || itemID.eventID.map(openedEventIDs(defaults: defaults).contains) == true
    }

    private static func openedEventIDs(defaults: UserDefaults) -> [String] {
        defaults.stringArray(forKey: defaultsKey) ?? []
    }
}

nonisolated extension EventBasedTimelineItemProtocol {
    var isNyutagViewOnce: Bool {
        (self as? ImageRoomTimelineItem)?.content.nyutagViewOnce == true
    }
}

extension TimelineControllerProtocol {
    /// Моки протокола метку не поддерживают — у них фото уходит обычным.
    func nyutagSendImage(url: URL,
                         thumbnailURL: URL,
                         imageInfo: ImageInfo,
                         caption: String?,
                         isViewOnce: Bool,
                         requestHandle: @MainActor (SendAttachmentJoinHandleProtocol) -> Void) async -> Result<Void, TimelineControllerError> {
        if isViewOnce, let controller = self as? TimelineController {
            return await controller.sendImage(url: url, thumbnailURL: thumbnailURL, imageInfo: imageInfo, caption: caption,
                                              extraContentJSON: NyutagViewOnce.extraContentJSON, requestHandle: requestHandle)
        }
        return await sendImage(url: url, thumbnailURL: thumbnailURL, imageInfo: imageInfo, caption: caption, requestHandle: requestHandle)
    }
}

/// Заглушка в ленте и одноразовый просмотр во весь экран. На скриншоте и при записи экрана фото скрыто.
struct NyutagViewOnceImageView: View {
    @Environment(\.timelineContext) private var context
    let timelineItem: ImageRoomTimelineItem

    @State private var isViewing = false
    @State private var isOpened = false

    private var canOpen: Bool {
        !timelineItem.isOutgoing && !isOpened && !NyutagViewOnceOpened.wasOpened(timelineItem.id)
    }

    var body: some View {
        TimelineStyler(timelineItem: timelineItem) {
            HStack(spacing: 8) {
                CompoundIcon(\.time)
                    .foregroundStyle(.compound.iconSecondary)
                Text(label)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canOpen else { return }
                NyutagViewOnceOpened.markOpened(timelineItem.id)
                isViewing = true
            }
        }
        .onAppear {
            // Открыли, а приложение убили до закрытия просмотра — удаление тогда не ушло, отправляем сейчас.
            if !timelineItem.isOutgoing, !isViewing, NyutagViewOnceOpened.wasOpened(timelineItem.id) {
                redact()
            }
        }
        .fullScreenCover(isPresented: $isViewing, onDismiss: redact) {
            NyutagViewOnceViewer(timelineItem: timelineItem, mediaProvider: context?.mediaProvider) { isViewing = false }
        }
    }

    private var label: String {
        if timelineItem.isOutgoing { return NyutagL10n.viewOnceSent }
        return canOpen ? NyutagL10n.viewOnceReceived : NyutagL10n.viewOnceOpened
    }

    private func redact() {
        isOpened = true
        context?.send(viewAction: .nyutagViewOnceOpened(itemID: timelineItem.id))
    }
}

private struct NyutagViewOnceViewer: View {
    let timelineItem: ImageRoomTimelineItem
    let mediaProvider: MediaProviderProtocol?
    let onDismiss: () -> Void

    @State private var isCaptured = UIScreen.main.isCaptured

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !isCaptured {
                NyutagScreenshotShield {
                    LoadableImage(mediaSource: timelineItem.content.imageInfo.source,
                                  mediaType: .generic,
                                  blurhash: nil,
                                  size: timelineItem.content.imageInfo.size,
                                  mediaProvider: mediaProvider) {
                        ProgressView().tint(.white)
                    }
                    .scaledToFit()
                }
                .ignoresSafeArea()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isCaptured = UIScreen.main.isCaptured
        }
    }
}

/// Скрывает содержимое на скриншотах и записи экрана: слой поля пароля (`isSecureTextEntry`) система в снимок не пускает.
/// Если такого слоя нет (iOS поменяла устройство поля), содержимое показывается как обычно — запись экрана всё равно
/// прячет фото через `UIScreen.isCaptured`.
struct NyutagScreenshotShield<Content: View>: UIViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeUIView(context: Context) -> UIView {
        let host = UIHostingController(rootView: content())
        host.view.backgroundColor = .clear
        let container = UIView()
        container.isUserInteractionEnabled = false
        let shield = Self.secureCanvas() ?? UIView()
        let hostView: UIView = host.view
        for view in [shield, hostView] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        container.addSubview(shield)
        shield.addSubview(hostView)
        NSLayoutConstraint.activate(Self.pin(shield, to: container) + Self.pin(hostView, to: shield))
        context.coordinator.host = host
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.host?.rootView = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var host: UIHostingController<Content>?
    }

    /// Внутренний холст защищённого поля; его подвиды на снимке экрана пустые.
    static func secureCanvas() -> UIView? {
        let field = UITextField()
        field.isSecureTextEntry = true
        guard let canvas = field.layer.sublayers?.first?.delegate as? UIView else {
            MXLog.warning("Nyutag view-once: secure canvas not found, screenshots are not blocked")
            return nil
        }
        canvas.subviews.forEach { $0.removeFromSuperview() }
        canvas.isUserInteractionEnabled = false
        return canvas
    }

    private static func pin(_ view: UIView, to parent: UIView) -> [NSLayoutConstraint] {
        [view.topAnchor.constraint(equalTo: parent.topAnchor),
         view.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
         view.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
         view.trailingAnchor.constraint(equalTo: parent.trailingAnchor)]
    }
}
