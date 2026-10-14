//
//  performDrop.swift
//  NotchNook
//
//  Created by Igor Marcossi on 24/06/24.
//

import Foundation
import SwiftUI

extension NotchView.ShapeModifier {
    
    func performDrop(info: NSDraggingInfo) -> Bool {
        let isTray = state.hoveredDropTargetID == TrayView.id
        let targetedPipeline = allPipelines.first(where: { $0.id == state.hoveredDropTargetID })
        let fileManager = FileManager.default
        let appTempDir = fileManager.temporaryDirectory.appendingPathComponent("NotchNookTemp")
        
        let callBack: ([URL]) -> Void = { urls in
            if !isTray, let targetedPipeline {
                targetedPipeline.action(urls, .zero)
                cleanupTemporaryDirectory(appTempDir)
            } else {
                tray.addFilesFromURLs(urls)
            }
        }
        
        var hasFiles = false
        let loadItemGroup = DispatchGroup()
        let pasteboard = info.draggingPasteboard
        let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        
        if let fileURLs, !fileURLs.isEmpty {
            // MARK: Handle files
            hasFiles = true
            DispatchQueue.main.async {
                let processedURLs = fileURLs.compactMap { url in
                    url.path.contains(NSTemporaryDirectory()) ? handleTemporaryFile(url, fileManager, appTempDir) : url
                }
                callBack(processedURLs)
            }
        } else if let text = extractTextOrURL(from: pasteboard) {
            // MARK: Handle text or URL ONLY if no real files
            hasFiles = true
            handleDroppedText(text, callBack)
        }
        
        guard let promiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver] else {
            finishDragging(close: true)
            return false
        }
        
        handlePromiseReceivers(promiseReceivers, fileManager, appTempDir, loadItemGroup, callBack)
        
        loadItemGroup.notify(queue: .main) {
            finishDragging(close: !hasFiles && !isTray)
        }
        
        return true
    }
    
    private func extractTextOrURL(from pasteboard: NSPasteboard) -> String? {
        let urlTypes: [NSPasteboard.PasteboardType] = [
            .init("public.url"),
            .init("CorePasteboardFlavorType 0x75726C20"),
            .init("Apple URL pasteboard type"),
            .fileURL
        ]
        
        let textTypes: [NSPasteboard.PasteboardType] = [
            .init("public.utf8-plain-text"),
            .init("NSStringPboardType")
        ]
        
        for type in urlTypes {
            if let data = pasteboard.data(forType: type), let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        
        for type in textTypes {
            if let data = pasteboard.data(forType: type), let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        
        return nil
    }
    
    private func handleDroppedText(_ text: String, _ callBack: @escaping ([URL]) -> Void) {
        DispatchQueue.main.async {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            
            if let url = URL(string: text), NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
                let weblocURL = tempDir.appendingPathComponent("shared_url.webloc")
                do {
                    try (["URL": text] as NSDictionary).write(to: weblocURL)
                    callBack([weblocURL])
                } catch {
                    print("Error creating .webloc file: \(error)")
                    let fallbackURL = weblocURL.appendingPathExtension("url")
                    do {
                        try "[InternetShortcut]\nURL=\(text)".write(to: fallbackURL, atomically: true, encoding: .utf8)
                        callBack([fallbackURL])
                    } catch {
                        print("Fallback URL file creation failed: \(error)")
                    }
                }
            } else {
                let txtURL = tempDir.appendingPathComponent("shared_text.txt")
                do {
                    try text.write(to: txtURL, atomically: true, encoding: .utf8)
                    callBack([txtURL])
                } catch {
                    print("Error creating text file: \(error)")
                }
            }
        }
    }
    
    private func handlePromiseReceivers(_ receivers: [NSFilePromiseReceiver], _ fileManager: FileManager, _ appTempDir: URL, _ group: DispatchGroup, _ callBack: @escaping ([URL]) -> Void) {
        for receiver in receivers {
            group.enter()
            do {
                try fileManager.createDirectory(at: appTempDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating app temp directory: \(error)")
            }
            
            receiver.receivePromisedFiles(atDestination: appTempDir, options: [:], operationQueue: .main) { fileURL, error in
                defer { group.leave() }
                if let error = error {
                    print("Error receiving file: \(error)")
                } else {
                    DispatchQueue.main.async {
                        callBack([fileURL])
                    }
                }
            }
        }
    }
    
    private func handleTemporaryFile(_ originalURL: URL, _ fileManager: FileManager, _ appTempDir: URL) -> URL? {
        do {
            try fileManager.createDirectory(at: appTempDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating app temp directory: \(error)")
        }
        
        let newURL = appTempDir.appendingPathComponent(originalURL.lastPathComponent)
        do {
            try fileManager.moveItem(at: originalURL, to: newURL)
            return newURL
        } catch {
            print("Error moving file: \(error)")
            return nil
        }
    }
    
}
