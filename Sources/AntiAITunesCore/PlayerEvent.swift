/// The playback state the Music app reports.
public enum PlayerState: Equatable, Sendable {
    case playing, paused, stopped

    /// Accepts `playerInfo` values ("Playing") and AppleScript values ("playing").
    init?(text: String) {
        switch text.lowercased() {
        case "playing": self = .playing
        case "paused": self = .paused
        case "stopped": self = .stopped
        default: return nil
        }
    }
}

/// A song as the Music app describes it.
public struct Track: Equatable, Sendable {
    public let name: String
    public let artist: String
    public let album: String

    public init(name: String, artist: String, album: String) {
        self.name = name
        self.artist = artist
        self.album = album
    }

    /// Identifies a song across repeated notifications. Streamed songs carry no persistent ID.
    public var key: String {
        [name, artist, album].map(Normalizer.normalize).joined(separator: "\u{1F}")
    }
}

/// One update from the Music app.
public enum PlayerEvent: Equatable, Sendable {
    /// A message about a song, with the state when the message has one.
    case track(Track, PlayerState?)
    /// A message with only the playback state.
    case state(PlayerState)

    /// Parses a `com.apple.Music.playerInfo` notification. Returns nil when it holds neither a song nor a state.
    public init?(userInfo: [AnyHashable: Any]) {
        self.init(
            name: userInfo["Name"] as? String,
            artist: userInfo["Artist"] as? String,
            album: userInfo["Album"] as? String,
            state: (userInfo["Player State"] as? String).flatMap(PlayerState.init(text:))
        )
    }

    /// Parses the result of the launch read: player state, name, artist and album, in that order.
    public init?(snapshot fields: [String]) {
        guard fields.count == 4 else { return nil }
        self.init(name: fields[1], artist: fields[2], album: fields[3], state: PlayerState(text: fields[0]))
    }

    private init?(name: String?, artist: String?, album: String?, state: PlayerState?) {
        if let name, !name.isEmpty {
            self = .track(Track(name: name, artist: artist ?? "", album: album ?? ""), state)
        } else if let state {
            self = .state(state)
        } else {
            return nil
        }
    }
}
