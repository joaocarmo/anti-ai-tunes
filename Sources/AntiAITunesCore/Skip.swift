/// A song the app skipped, with what **Not AI** needs to undo it.
public struct Skip: Equatable, Sendable {
    /// The notification category of skip notifications.
    public static let category = "skip"
    /// The identifier of the **Not AI** notification action.
    public static let notAIAction = "notAI"

    let key: String
    let parts: [String]
    let artists: String
    /// Whether the dislike before the skip stuck, so **Not AI** must clear it.
    var disliked = false

    /// The notification payload that `init?(action:userInfo:)` reads back.
    public var userInfo: [AnyHashable: Any] {
        ["key": key, "parts": parts, "artists": artists, "disliked": disliked]
    }
}

extension Skip {
    /// Creates a skip from a notification response.
    ///
    /// Returns nil unless the response is the **Not AI** action with a skip payload. Payloads without `disliked` come
    /// from older versions, which never disliked.
    public init?(action: String, userInfo: [AnyHashable: Any]) {
        guard action == Self.notAIAction, let key = userInfo["key"] as? String,
            let parts = userInfo["parts"] as? [String], let artists = userInfo["artists"] as? String
        else { return nil }
        self.init(key: key, parts: parts, artists: artists, disliked: userInfo["disliked"] as? Bool ?? false)
    }
}

/// The result of an attempt to dislike a song.
public enum Dislike: String, Sendable {
    /// The read-back says the song is disliked.
    case accepted
    /// The read-back says the song is not disliked: Music ignored it.
    case ignored
    /// The attempt or the read-back failed.
    case failed

    /// Creates the result from the read-back, which is nil when the attempt failed.
    init(readBack: Bool?) {
        switch readBack {
        case true?: self = .accepted
        case false?: self = .ignored
        case nil: self = .failed
        }
    }
}
