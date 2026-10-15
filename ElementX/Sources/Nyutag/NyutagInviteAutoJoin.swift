//
// Нютаг — автоприём приглашений: новая переписка или звонок не должны выглядеть как «приглашение в чат».
// Сервер закрытый (без федерации), чужих нет — приглашение от участника принимаем сразу, как в Telegram/WhatsApp.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine
import Foundation

final class NyutagInviteAutoJoin {
    private var cancellable: AnyCancellable?
    private var attempted = Set<String>()
    
    func start(provider: RoomSummaryProviderProtocol, client: ClientProxyProtocol) {
        cancellable = provider.roomListPublisher
            .map { summaries in
                summaries.compactMap { summary -> String? in
                    guard case .invite = summary.joinRequestType else { return nil }
                    return summary.id
                }
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak client] roomIDs in
                guard let self, let client else { return }
                let newIDs = roomIDs.filter { !attempted.contains($0) }
                guard !newIDs.isEmpty else { return }
                attempted.formUnion(newIDs)
                Task {
                    for roomID in newIDs {
                        MXLog.info("Nyutag: auto-joining invited room \(roomID)")
                        if case let .failure(error) = await client.joinRoom(roomID, via: []) {
                            MXLog.error("Nyutag: auto-join failed for \(roomID): \(error)")
                        }
                    }
                }
            }
    }
}
