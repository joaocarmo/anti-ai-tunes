import AntiAITunesCore
import AppKit

/// Sends Apple Events to the Music app.
@MainActor
struct MusicControllerAdapter: MusicControlling {
    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }

    func currentTrackFields() -> [String]? {
        (Self.snapshotScript?.executeAndReturnError(nil)).map { result in
            stride(from: 1, through: result.numberOfItems, by: 1).map { result.atIndex($0)?.stringValue ?? "" }
        }
    }

    func nextTrack() {
        _ = Self.nextTrackScript?.executeAndReturnError(nil)
    }

    func previousTrack() {
        _ = Self.previousTrackScript?.executeAndReturnError(nil)
    }

    func dislikeCurrentTrack() -> Bool? {
        Self.dislikeScript?.executeAndReturnError(nil)?.booleanValue
    }

    func clearDislike() {
        _ = Self.clearDislikeScript?.executeAndReturnError(nil)
    }

    // The timeouts keep a busy Music app from blocking the menu for the default 2 minutes.
    private static let nextTrackScript = NSAppleScript(
        source: """
            tell application "Music"
                with timeout of 5 seconds
                    next track
                end timeout
            end tell
            """)

    private static let previousTrackScript = NSAppleScript(
        source: """
            tell application "Music"
                with timeout of 5 seconds
                    previous track
                end timeout
            end tell
            """)

    // A shorter timeout, because the skip waits for the dislike.
    private static let dislikeScript = NSAppleScript(
        source: """
            tell application "Music"
                with timeout of 2 seconds
                    set disliked of current track to true
                    return disliked of current track
                end timeout
            end tell
            """)

    private static let clearDislikeScript = NSAppleScript(
        source: """
            tell application "Music"
                with timeout of 2 seconds
                    set disliked of current track to false
                end timeout
            end tell
            """)

    private static let snapshotScript = NSAppleScript(
        source: """
            tell application "Music"
                with timeout of 5 seconds
                    if player state is stopped then return {"stopped", "", "", ""}
                    return {player state as text, name of current track, artist of current track, album of current track}
                end timeout
            end tell
            """)
}
