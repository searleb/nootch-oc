import SwiftUI
import AppKit
import Defaults

/// Runs `ClaudeUsageEngine` every two seconds while the Claude Usage widget is
/// in the Nook, publishes its snapshots, and drives the two Claude live
/// activities. One instance only: nootch has a window per screen, and a
/// watcher per view would fire every alert twice.
@Observable
final class ClaudeUsageStore {
    static let shared = ClaudeUsageStore()

    private(set) var profiles: [ClaudeProfileSnapshot] = []
    /// False until the first poll has read today's history.
    private(set) var isLoaded = false
    /// FIFO of finished turns waiting their few seconds in the notch.
    private(set) var finishedQueue: [ClaudeFinishedAlert] = []

    var currentFinished: ClaudeFinishedAlert? { finishedQueue.first }
    /// The longest-running turn across profiles.
    var workingSession: ClaudeLiveSession? { profiles.flatMap(\.live).min { $0.started < $1.started } }

    @ObservationIgnored private let queue = DispatchQueue(label: "lo.cafe.notchnook.claude-usage", qos: .utility)
    @ObservationIgnored private var timer: DispatchSourceTimer?
    @ObservationIgnored private var prefsTask: Task<Void, Never>?
    @ObservationIgnored private var workingShown = false

    private init() {
        // Starts and stops with the widget being in the Nook; nothing is read otherwise.
        prefsTask = Task { @MainActor [weak self] in
            for await settings in Defaults.updates(.nookSettings) {
                self?.setRunning(settings.enabledWidgets.contains(.claudeUsage))
            }
        }
    }

    deinit { prefsTask?.cancel() }

    // MARK: Lifecycle

    private func setRunning(_ running: Bool) {
        if running { start() } else { stop() }
    }

    private func start() {
        guard timer == nil else { return }
        let engine = ClaudeUsageEngine(home: FileManager.default.homeDirectoryForCurrentUser)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: 2, leeway: .milliseconds(500))
        source.setEventHandler { [weak self] in
            // The engine is only ever touched on this queue.
            let output = engine.poll()
            DispatchQueue.main.async { self?.apply(output) }
        }
        timer = source
        source.resume()
    }

    private func stop() {
        guard let source = timer else { return }
        source.cancel()
        timer = nil
        profiles = []
        isLoaded = false
        finishedQueue.removeAll()
        setWorking(false)
        MainActor.assumeIsolated { ActiveLiveActivitiesManager.shared.removeSync(.claudeFinished) }
    }

    // MARK: Output

    private func apply(_ output: ClaudeUsageEngine.Output) {
        guard timer != nil else { return }   // a poll already in flight when the widget was removed
        if output.profiles != profiles { profiles = output.profiles }
        if !isLoaded { isLoaded = true }
        setWorking(workingSession != nil)

        let settings = Defaults[.claudeUsageWidgetSettings]
        let alerts = ClaudeFinishedAlert.alerts(from: output.finished, profiles: output.profiles,
                                                notify: settings.notifyOnFinish, minimumSeconds: settings.minFinishSeconds)
        for alert in alerts { enqueue(alert, playSound: settings.playSound) }
    }

    private func setWorking(_ working: Bool) {
        guard working != workingShown else { return }
        workingShown = working
        MainActor.assumeIsolated {
            if working { ActiveLiveActivitiesManager.shared.insertSync(.claudeWorking) }
            else { ActiveLiveActivitiesManager.shared.removeSync(.claudeWorking) }
        }
    }

    // MARK: Finished alerts (same queue-and-dismiss shape as NookTimersStore)

    private func enqueue(_ alert: ClaudeFinishedAlert, playSound: Bool) {
        let wasEmpty = finishedQueue.isEmpty
        finishedQueue.append(alert)
        if playSound { NSSound(named: NSSound.Name("Hero"))?.play() }
        if wasEmpty {
            MainActor.assumeIsolated { ActiveLiveActivitiesManager.shared.insertSync(.claudeFinished) }
            scheduleNextDismiss()
        }
    }

    private func popFinished() {
        guard !finishedQueue.isEmpty else { return }
        finishedQueue.removeFirst()
        if finishedQueue.isEmpty {
            MainActor.assumeIsolated { ActiveLiveActivitiesManager.shared.removeSync(.claudeFinished) }
        } else {
            scheduleNextDismiss()
        }
    }

    private func scheduleNextDismiss() {
        let dismiss = Timer(timeInterval: 5, repeats: false) { [weak self] _ in self?.popFinished() }
        RunLoop.main.add(dismiss, forMode: .common)
        TimersManager.shared.replaceMainThreadTimer("ClaudeFinishedLADismiss", timer: dismiss)
    }
}
