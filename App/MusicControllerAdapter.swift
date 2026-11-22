import AntiAITunesCore
import AppKit
import Carbon

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

    func dislikeCurrentTrack(name: String, artist: String, album: String) -> String? {
        // Calls the script's `dislike` handler. Arguments go in as descriptors, never as script text.
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kASAppleScriptSuite), eventID: AEEventID(kASSubroutineEvent),
            targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID))
        event.setDescriptor(NSAppleEventDescriptor(string: "dislike"), forKeyword: AEKeyword(keyASSubroutineName))
        let arguments = NSAppleEventDescriptor.list()
        for (index, value) in [name, artist, album].enumerated() {
            arguments.insert(NSAppleEventDescriptor(string: value), at: index + 1)
        }
        event.setDescriptor(arguments, forKeyword: AEKeyword(keyDirectObject))
        return Self.dislikeScript?.executeAppleEvent(event, error: nil).stringValue
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

    // A shorter timeout, because the skip waits for the dislike. Text keeps a failed run apart from `false`. The
    // song check stops a dislike from landing on a song that started after the match.
    private static let dislikeScript = NSAppleScript(
        source: """
            on dislike(trackName, trackArtist, trackAlbum)
                tell application "Music"
                    with timeout of 2 seconds
                        if (get {name, artist, album} of current track) is not {trackName, trackArtist, trackAlbum} then
                            return "other song"
                        end if
                        set disliked of current track to true
                        return (disliked of current track) as text
                    end timeout
                end tell
            end dislike
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
