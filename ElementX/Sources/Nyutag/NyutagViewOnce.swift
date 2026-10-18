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

/// Открытые в этом запуске фото: пока удаление не дошло до сервера, второй раз не откроются, даже если ячейку пересоздали.
@MainActor
enum NyutagViewOnceOpened {
    private(set) static var itemIDs = Set<TimelineItemIdentifier.UniqueID>()

    static func markOpened(_ itemID: TimelineItemIdentifier.UniqueID) {
        itemIDs.insert(itemID)
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

/// Заглушка в ленте и одноразовый просмотр во весь экран. При записи экрана фото скрыто.
struct NyutagViewOnceImageView: View {
    @Environment(\.timelineContext) private var context
    let timelineItem: ImageRoomTimelineItem

    @State private var isViewing = false
    @State private var isOpened = false

    private var canOpen: Bool {
        !timelineItem.isOutgoing && !isOpened && !NyutagViewOnceOpened.itemIDs.contains(timelineItem.id.uniqueID)
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
                isViewing = true
            }
        }
        .fullScreenCover(isPresented: $isViewing, onDismiss: markOpened) {
            NyutagViewOnceViewer(timelineItem: timelineItem, mediaProvider: context?.mediaProvider) { isViewing = false }
        }
    }

    private var label: String {
        if timelineItem.isOutgoing { return NyutagL10n.viewOnceSent }
        return canOpen ? NyutagL10n.viewOnceReceived : NyutagL10n.viewOnceOpened
    }

    private func markOpened() {
        isOpened = true
        NyutagViewOnceOpened.markOpened(timelineItem.id.uniqueID)
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
                LoadableImage(mediaSource: timelineItem.content.imageInfo.source,
                              mediaType: .generic,
                              blurhash: nil,
                              size: timelineItem.content.imageInfo.size,
                              mediaProvider: mediaProvider) {
                    ProgressView().tint(.white)
                }
                .scaledToFit()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isCaptured = UIScreen.main.isCaptured
        }
    }
}
