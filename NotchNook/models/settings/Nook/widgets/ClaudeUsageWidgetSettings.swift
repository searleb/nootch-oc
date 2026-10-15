import SwiftUI

struct ClaudeUsageWidgetSettings: WidgetPrefs {
    var size: NookGrid.Size = .init(width: 4, height: 2)
    var notifyOnFinish: Bool = true
    var playSound: Bool = true
    /// Turns shorter than this finish without an alert.
    var minFinishSeconds: Double = 10
}
