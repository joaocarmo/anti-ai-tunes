import AntiAITunesCore
import UserNotifications

/// Posts notifications through the system notification center.
@MainActor
struct NotifierAdapter: Notifying {
    /// Asks for permission. Without it, posts are dropped and skipping still works.
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
