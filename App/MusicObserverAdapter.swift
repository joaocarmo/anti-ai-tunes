import AntiAITunesCore
import Foundation

/// Forwards the Music app's `com.apple.Music.playerInfo` notifications as player events.
final class MusicObserverAdapter {
    private let token: NSObjectProtocol

    init(onEvent: @escaping @MainActor @Sendable (PlayerEvent) -> Void) {
        token = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { notification in
            guard let event = PlayerEvent(userInfo: notification.userInfo ?? [:]) else { return }
            MainActor.assumeIsolated { onEvent(event) }
        }
    }
}
