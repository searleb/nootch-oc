//
//  AppDelegate.swift
//  NotchNook
//
//  Created by Igor Marcossi on 12/05/24.
//
import Foundation
import SwiftUI
#if !SETAPP_BUILD
import Sparkle
#endif
import AppKit
import SwiftDate
import SwiftData
import Defaults

@objc class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: NSWindowController? = nil
    var windowsManager: WindowsManager?
    var nsMenu: NSMenu?
    var appInitialized = false
#if !SETAPP_BUILD
    let updaterDelegate = UpdaterDelegate()
    let updaterController: SPUStandardUpdaterController
#endif
    
    override init() {
        SwiftDate.defaultRegion = Region.local
#if !SETAPP_BUILD
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: updaterDelegate, userDriverDelegate: updaterDelegate)
#endif
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        windowsManager?.settingsWindowController?.show()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize (in memory ig) all singletons
        _ = CalendarManager.shared
        _ = ShortcutsManager.shared
        _ = MediaManager.shared
        _ = PowerMonitor.shared
        _ = VolumeMonitor.shared
        _ = CurrentWallpaperManager.shared
        _ = BluetoothManager.shared
        _ = FullscreenMonitor.shared

        // Seed/repair the default notes ONCE at launch, before any window (and
        // thus any NotesWidgetView) is built. This used to live in the widget's
        // .onAppear, which fires every time the Nook opens AND once per screen —
        // racing the SwiftData @Query (empty on first read) into re-seeding, so
        // the store grew past 4 notes. Once notes.count > 4 the widget's
        // `prefix(4 - notes.count)` went negative and crashed on click.
        seedAndPruneDefaultNotes()

        windowsManager = WindowsManager.shared

//        ValueTransformer.setValueTransformer(NSAttributedStringTransformer(), forName: .nsAttributedString)

        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        
        appInitialized = true
    }
    
    /// Ensures the Notes store holds exactly the four default-icon notes when
    /// it's untouched, and repairs any drift (duplicate icons / overflow) left
    /// behind by the old per-appearance seeding. Runs once, at launch.
    @MainActor
    private func seedAndPruneDefaultNotes() {
        let defaultIcons = ["diamond.fill", "triangle.fill", "circle.fill", "app.fill"]
        let context = RootView.sharedModelContainer.mainContext
        do {
            let notes = try context.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt)]))

            // Prune duplicate-icon notes that the old seeding may have inserted.
            // Keep the oldest note per icon; only drop a duplicate if it's still
            // empty (never edited) so we never delete real user content.
            var seenIcons = Set<String>()
            for note in notes {
                if seenIcons.contains(note.icon) {
                    if note.richText.string.isEmpty && note.codeText.isEmpty {
                        context.delete(note)
                    }
                } else {
                    seenIcons.insert(note.icon)
                }
            }

            // Seed only a genuinely-empty store (after pruning). A store that
            // already has notes is left alone — never force it back to four.
            let remaining = try context.fetch(FetchDescriptor<Note>())
            if remaining.isEmpty {
                for icon in defaultIcons {
                    context.insert(Note(icon: icon))
                }
            }

            if context.hasChanges { try context.save() }
        } catch {
            print("[Notes] seedAndPruneDefaultNotes failed: \(error)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HUDManager.enableSystemHUD()
        // Flush any pending SwiftData writes before the process exits.
        do {
            try RootView.sharedModelContainer.mainContext.save()
        } catch {
            print("[Notes] applicationWillTerminate save failed: \(error)")
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !appInitialized {
            windowsManager?.settingsWindowController?.show()
        }
        return true
    }
    
    func setupMenu() {
        let mainMenu = NSMenu(title: "MainMenu")
        let menuItem = mainMenu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        
        let submenu = NSMenu()
        submenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        submenu.addItem(withTitle: "Undo", action: #selector(EditMenuActions.undo(_:)), keyEquivalent: "z")
        submenu.addItem(withTitle: "Redo", action: #selector(EditMenuActions.redo(_:)), keyEquivalent: "Z")
        submenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        submenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        submenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        submenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        mainMenu.setSubmenu(submenu, for: menuItem)
        NSApp.mainMenu = mainMenu
    }
    
    @objc protocol EditMenuActions {
        func redo(_ sender: AnyObject)
        func undo(_ sender: AnyObject)
    }
}
