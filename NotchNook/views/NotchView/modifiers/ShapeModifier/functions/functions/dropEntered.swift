//
//  dropEntered.swift
//  NotchNook
//
//  Created by Igor Marcossi on 25/06/24.
//

import SwiftUI

extension NotchView.ShapeModifier {
    func dropEntered(info: NSDraggingInfo) {
        withAnimation(NotchView.intenseAnimation) {
            notchNook.mode = .dragging
        }
        
        let actionsToShow = allPipelines.filter { action in
            guard let pasteboardTypes = info.draggingPasteboard.types else { return false }
            
            return action.allowedFileTypes.contains { pasteboardTypes.contains($0) }
        }
                
        DispatchQueue.main.async {
            withAnimation(NotchView.intenseAnimation) {
                state.availableActions = actionsToShow
            }
        }
    }
}
