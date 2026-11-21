/// A song the app skipped, with what **Not AI** needs to undo it.
public struct Skip: Equatable, Sendable {
    /// The notification category of skip notifications.
    public static let category = "skip"
    /// The identifier of the **Not AI** notification action.
    public static let notAIAction = "notAI"

    let key: String
    let parts: [String]
    let artists: String

    /// The notification payload that `init?(action:userInfo:)` reads back.
    public var userInfo: [AnyHashable: Any] { ["key": key, "parts": parts, "artists": artists] }
}

extension Skip {
    /// Creates a skip from a notification response.
    ///
    /// Returns nil unless the response is the **Not AI** action with a skip payload.
    public init?(action: String, userInfo: [AnyHashable: Any]) {
        guard action == Self.notAIAction, let key = userInfo["key"] as? String,
            let parts = userInfo["parts"] as? [String], let artists = userInfo["artists"] as? String
        else { return nil }
        self.init(key: key, parts: parts, artists: artists)
    }
}
