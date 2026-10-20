import XCTest
import SwiftUI
@testable import NotchNook

/// The closed notch draws larger while `hovering` is true. Leaving the notch must always clear it,
/// even when the Nook deliberately stays open (typing, locked): it may then close through the
/// outside-click path, which never touches `hovering`, and stay stuck a few pixels too big.
final class NotchHoverStateTests: XCTestCase {
    override func tearDown() {
        EnvironmentValues().notchNook.locked = false
        super.tearDown()
    }

    func testLeavingALockedNotchStillClearsHovering() {
        let state = NotchViewModel()
        state.hovering = true
        EnvironmentValues().notchNook.locked = true   // the Nook must stay open
        NotchView.GesturesModifier(state: state, disableNotchNook: false).onHover(false)
        XCTAssertFalse(state.hovering, "the pointer left, so the closed notch must not keep its hover size")
    }
}
