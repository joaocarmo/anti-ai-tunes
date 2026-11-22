import AntiAITunesCore
import UserNotifications

/// Posts notifications through the system notification center and forwards their **Not AI** action.
@MainActor
final class NotifierAdapter: NSObject, Notifying, UNUserNotificationCenterDelegate {
    /// Called when someone chooses **Not AI** on a notification.
    var onNotAI: @MainActor (Skip) -> Void = { _ in }

    /// Creates a notifier, makes it the notification delegate and asks for permission.
    ///
    /// Without permission, posts are dropped and skipping still works.
    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let notAI = UNNotificationAction(identifier: Skip.notAIAction, title: "Not AI", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Skip.category, actions: [notAI], intentIdentifiers: [], options: [])
        ])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(title: String, body: String, skip: Skip) {
        let content = Self.content(title: title, body: body)
        content.categoryIdentifier = Skip.category
        content.userInfo = skip.userInfo
        Self.add(content)
    }

    func post(title: String, body: String) {
        Self.add(Self.content(title: title, body: body))
    }

    private static func content(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        return content
    }

    private static func add(_ content: UNNotificationContent) {
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // Without this, notifications are silent while the app is in front, such as while its menu is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard
            let skip = Skip(
                action: response.actionIdentifier, userInfo: response.notification.request.content.userInfo)
        else { return }
        await forward(skip)
    }

    private func forward(_ skip: Skip) {
        onNotAI(skip)
    }
}
