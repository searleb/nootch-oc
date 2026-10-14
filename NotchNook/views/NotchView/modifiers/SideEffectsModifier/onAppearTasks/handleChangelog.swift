//
//  handleChangelog.swift
//  NotchNook
//
//  Created by Igor Marcossi on 24/06/24.
//

import Foundation
import SwiftUI

extension NotchView.SideEffectsModifier {
    func handleChangelog() {
        let currentVersionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

        if shouldShowChangelog(lastVersionNumber: lastVersionNumber, currentVersionNumber: currentVersionNumber) {
            showChangelog()
            lastVersionNumber = currentVersionNumber
        }
    }
    
    /// Compare major and minor version components
    func shouldShowChangelog(lastVersionNumber: String, currentVersionNumber: String) -> Bool {
        let lastComponents = lastVersionNumber.split(separator: ".")
        let currentComponents = currentVersionNumber.split(separator: ".")
        
        guard lastComponents.count >= 2 && currentComponents.count >= 2 else {
            return lastVersionNumber != currentVersionNumber
        }
        
        if lastComponents[1] != currentComponents[1] { return true }
        if lastComponents[0] != currentComponents[0] { return true }
        return false
    }
}
