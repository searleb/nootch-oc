//
//  RemindersTodoStore.swift
//  NotchNook
//

import AppKit
import EventKit
import Defaults

extension Defaults.Keys {
    /// The Reminders list the to-do widget reads and writes, once found or created.
    static let todoRemindersListID = Key<String?>("todoRemindersListID", default: nil)
}

/// Keeps the to-do widget's tasks in a Reminders list, so they live in Reminders (synced
/// through iCloud, safe from anything that happens to NotchNook's own storage) rather
/// than in the app. One instance: nootch has a window per screen.
@Observable
final class RemindersTodoStore {
    static let shared = RemindersTodoStore()
    static let listTitle = "NotchNook"

    enum Access: Equatable {
        case unknown, needsPermission, denied, granted
    }

    private(set) var access: Access = .unknown
    private(set) var tasks: [TodoTask] = []
    /// False until the list has been read once after access was granted.
    private(set) var isLoaded = false
    /// Why the list could not be read or written, when it could not.
    private(set) var problem: String?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var started = false
    @ObservationIgnored private var fetchGeneration = 0

    private init() {}

    /// Starts following the list. Asks for nothing: the widget offers the permission prompt.
    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.reload()
        }
        refreshAccess()
    }

    func requestAccess() {
        store.requestFullAccessToReminders { [weak self] _, _ in
            DispatchQueue.main.async { self?.refreshAccess() }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Reading

    private func refreshAccess() {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized:
            access = .granted
            reload()
        case .notDetermined:
            access = .needsPermission
        default:
            // Denied, restricted or write-only: the widget cannot show the list.
            access = .denied
        }
    }

    private func reload() {
        guard access == .granted else { return }
        guard let list = resolveList() else {
            problem = String(localized: "Couldn't find or create the NotchNook list in Reminders.")
            isLoaded = true
            return
        }
        fetchGeneration += 1
        let generation = fetchGeneration
        store.fetchReminders(matching: store.predicateForReminders(in: [list])) { [weak self] reminders in
            let fetched = (reminders ?? []).map(Self.task)
            DispatchQueue.main.async {
                // A newer fetch started meanwhile; it has the fresher answer.
                guard let self, generation == self.fetchGeneration else { return }
                self.tasks = fetched
                self.problem = nil
                self.isLoaded = true
            }
        }
    }

    /// The saved list, else one titled "NotchNook" (an identifier can change after an iCloud
    /// resync), else a new one in the account new reminders go to.
    private func resolveList() -> EKCalendar? {
        if let id = Defaults[.todoRemindersListID], let saved = store.calendar(withIdentifier: id),
           saved.allowedEntityTypes.contains(.reminder) {
            return saved
        }
        if let named = store.calendars(for: .reminder).first(where: { $0.title == Self.listTitle }) {
            Defaults[.todoRemindersListID] = named.calendarIdentifier
            return named
        }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = Self.listTitle
        guard let source = store.defaultCalendarForNewReminders()?.source
                ?? store.sources.first(where: { $0.sourceType == .calDAV || $0.sourceType == .local }) else { return nil }
        list.source = source
        do {
            try store.saveCalendar(list, commit: true)
        } catch {
            return nil
        }
        Defaults[.todoRemindersListID] = list.calendarIdentifier
        return list
    }

    private static func task(_ reminder: EKReminder) -> TodoTask {
        TodoTask(id: reminder.calendarItemIdentifier, title: reminder.title ?? "",
                 isCompleted: reminder.isCompleted, isPriority: TodoPriority.isStarred(reminderPriority: reminder.priority),
                 createdAt: reminder.creationDate, completedAt: reminder.completionDate)
    }

    // MARK: Writing

    func add(title: String) {
        guard access == .granted, let list = resolveList() else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list
        save(reminder)
    }

    func setCompleted(_ task: TodoTask, _ completed: Bool) {
        guard let reminder = reminder(for: task) else { return }
        reminder.isCompleted = completed
        update(task.id) { $0.isCompleted = completed; $0.completedAt = completed ? Date() : nil }
        save(reminder)
    }

    func setPriority(_ task: TodoTask, _ starred: Bool) {
        guard let reminder = reminder(for: task) else { return }
        reminder.priority = TodoPriority.reminderPriority(starred: starred)
        update(task.id) { $0.isPriority = starred }
        save(reminder)
    }

    func delete(_ task: TodoTask) {
        guard let reminder = reminder(for: task) else { return }
        tasks.removeAll { $0.id == task.id }
        do {
            try store.remove(reminder, commit: true)
        } catch {
            problem = String(localized: "Couldn't delete that reminder.")
            reload()
        }
    }

    private func reminder(for task: TodoTask) -> EKReminder? {
        store.calendarItem(withIdentifier: task.id) as? EKReminder
    }

    /// Shows the change at once; the store's change notification then reloads the truth.
    private func update(_ id: String, _ change: (inout TodoTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[index])
    }

    private func save(_ reminder: EKReminder) {
        do {
            try store.save(reminder, commit: true)
        } catch {
            problem = String(localized: "Couldn't save to Reminders.")
        }
        reload()
    }
}
