//
// SPDX-License-Identifier: AGPL-3.0-only
//

import AVFoundation
import Combine
@testable import ElementX
import Testing

/// Нютаг: список выходов звука уходит в Element Call один раз, а не на каждое уведомление о смене маршрута.
/// Иначе Element Call заново выбирает выход, маршрут снова меняется — петля в десятки переключений в секунду.
struct CallScreenViewModelTests {
    @Test
    func repeatedRouteChangesSendTheOutputsListOnce() async throws {
        try #require(AVAudioSession.sharedInstance().currentRoute.outputs.first != nil, "No audio output to report on this device")

        let viewModel = makeViewModel()
        // Координатор веб-вида подставляет свой исполнитель JavaScript асинхронно — дожидаемся его и подменяем.
        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))
        var outputsUpdates = 0
        viewModel.context.javaScriptEvaluator = { script in
            if script.contains("setAvailableOutputDevices") {
                outputsUpdates += 1
            }
            return ""
        }

        for _ in 0..<20 {
            NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil)
        }
        try await Task.sleep(for: .milliseconds(500))

        #expect(outputsUpdates == 1)
    }

    private func makeViewModel() -> CallScreenViewModel {
        let clientProxy = ClientProxyMock()
        clientProxy.deviceID = "call-device-id"

        let roomProxy = JoinedRoomProxyMock(.init())

        let widgetDriver = ElementCallWidgetDriverMock()
        widgetDriver.messagePublisher = .init()
        widgetDriver.actions = PassthroughSubject<ElementCallWidgetDriverAction, Never>().eraseToAnyPublisher()
        widgetDriver.startBaseURLClientIDColorSchemeVoiceOnlyRageshakeURLAnalyticsConfigurationReturnValue = .success(URL.userDirectory)

        roomProxy.elementCallWidgetDriverDeviceIDReturnValue = widgetDriver

        return CallScreenViewModel(elementCallService: ElementCallServiceMock(.init()),
                                   configuration: .init(roomProxy: roomProxy,
                                                        clientProxy: clientProxy,
                                                        clientID: "io.element.elementx",
                                                        elementCallBaseURL: "https://call.element.io",
                                                        elementCallBaseURLOverride: nil,
                                                        voiceOnly: true,
                                                        colorScheme: .dark),
                                   allowPictureInPicture: true,
                                   appSettings: .volatile(),
                                   analyticsService: AnalyticsServiceMock(.init()))
    }
}
