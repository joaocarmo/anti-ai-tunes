import AntiAITunesCore
import AppKit

/// Sends Apple Events to the Music app.
enum MusicControllerAdapter {
    /// Reads the current song once. Returns nil when Music is not running or the read fails.
    @MainActor
    static func currentTrackSnapshot() -> PlayerEvent? {
        // Any Apple Event to Music would launch it.
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else {
            return nil
        }
        var error: NSDictionary?
        guard let result = snapshotScript?.executeAndReturnError(&error) else { return nil }
        let fields = stride(from: 1, through: result.numberOfItems, by: 1).map { result.atIndex($0)?.stringValue ?? "" }
        return PlayerEvent(snapshot: fields)
    }

    @MainActor private static let snapshotScript = NSAppleScript(
        source: """
            tell application "Music"
                if player state is stopped then return {"stopped", "", "", ""}
                return {player state as text, name of current track, artist of current track, album of current track}
            end tell
            """)
}
