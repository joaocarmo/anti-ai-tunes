import AntiAITunesCore
import AppKit

/// Sends Apple Events to the Music app.
@MainActor
struct MusicControllerAdapter: MusicControlling {
    /// Reads the current song once. Returns nil when Music is not running or the read fails.
    static func currentTrackSnapshot() -> PlayerEvent? {
        guard isMusicRunning else { return nil }
        var error: NSDictionary?
        guard let result = snapshotScript?.executeAndReturnError(&error) else { return nil }
        let fields = stride(from: 1, through: result.numberOfItems, by: 1).map { result.atIndex($0)?.stringValue ?? "" }
        return PlayerEvent(snapshot: fields)
    }

    func nextTrack() {
        guard Self.isMusicRunning else { return }
        _ = Self.nextTrackScript?.executeAndReturnError(nil)
    }

    // Any Apple Event to Music would launch it.
    private static var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }

    private static let nextTrackScript = NSAppleScript(source: #"tell application "Music" to next track"#)

    private static let snapshotScript = NSAppleScript(
        source: """
            tell application "Music"
                if player state is stopped then return {"stopped", "", "", ""}
                return {player state as text, name of current track, artist of current track, album of current track}
            end tell
            """)
}
