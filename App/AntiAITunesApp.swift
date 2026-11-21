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
            Text(model.menu.listStatus)
            Divider()
            Button("Quit Anti-AI Tunes") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let refresher: ListRefresher
    let coordinator: MatchCoordinator
    var menu: MenuState { MenuState(nowPlaying: coordinator.nowPlaying, list: refresher.list) }
    @ObservationIgnored private var observer: MusicObserverAdapter?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let refresher = ListRefresher(
            directory: support.appendingPathComponent("AntiAITunes"), http: URLSessionHTTPClient(), clock: SystemClock()
        )
        let coordinator = MatchCoordinator(
            music: MusicControllerAdapter(), notifier: NotifierAdapter(), listed: { refresher.names })
        self.refresher = refresher
        self.coordinator = coordinator
        refresher.onChange = { coordinator.recheck() }
        observer = MusicObserverAdapter { coordinator.handle($0) }
        coordinator.start()
        Task { await refresher.run() }
    }
}
