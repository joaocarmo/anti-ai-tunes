import AntiAITunesCore
import SwiftUI

@main
struct AntiAITunesApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Anti-AI Tunes", systemImage: "music.note") {
            ForEach(Array(model.menu.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
            Divider()
            Button("Quit Anti-AI Tunes") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private(set) var nowPlaying = NowPlaying.waiting
    var menu: MenuState { MenuState(nowPlaying) }
    @ObservationIgnored private var observer: MusicObserverAdapter?

    init() {
        observer = MusicObserverAdapter { [weak self] event in
            self?.nowPlaying.apply(event)
        }
        if let snapshot = MusicControllerAdapter.currentTrackSnapshot() {
            nowPlaying.apply(snapshot)
        }
    }
}
