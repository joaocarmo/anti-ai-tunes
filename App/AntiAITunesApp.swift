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
            if let skip = model.coordinator.lastSkip, let label = model.menu.notAI {
                Button(label) { Task { await model.coordinator.notAI(skip) } }
            }
            Divider()
            Menu("AI list") {
                ForEach(Array(model.menu.listDetails.enumerated()), id: \.offset) { _, line in
                    Text(line)
                }
            }
            if let warning = model.menu.warning {
                Text(warning)
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
    let store: Store
    let refresher: ListRefresher
    let coordinator: MatchCoordinator
    var menu: MenuState {
        MenuState(
            nowPlaying: coordinator.nowPlaying, list: refresher.list, lastSkip: coordinator.lastSkip,
            failure: store.failure)
    }
    @ObservationIgnored private var observer: MusicObserverAdapter?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let store = Store(directory: support.appendingPathComponent("AntiAITunes"))
        let refresher = ListRefresher(store: store, http: URLSessionHTTPClient(), clock: SystemClock())
        // Created here, in `App.init`, because the notification delegate must be set before launch finishes.
        let notifier = NotifierAdapter()
        let coordinator = MatchCoordinator(
            music: MusicControllerAdapter(), notifier: notifier, store: store, clock: SystemClock(),
            listed: { refresher.names })
        self.store = store
        self.refresher = refresher
        self.coordinator = coordinator
        refresher.onChange = { coordinator.recheck() }
        notifier.onNotAI = { skip in Task { await coordinator.notAI(skip) } }
        observer = MusicObserverAdapter { coordinator.handle($0) }
        coordinator.start()
        Task { await refresher.run() }
    }
}
