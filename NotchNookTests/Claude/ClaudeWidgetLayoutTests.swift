import XCTest
import SwiftUI
@testable import NotchNook

/// Renders the widget's real content and measures where its pixels start, because a
/// `ScrollView` clips exactly at its bounds and anything flush against the edge loses its first pixels.
@MainActor
final class ClaudeWidgetLayoutTests: XCTestCase {
    private func profiles() -> [ClaudeProfileSnapshot] {
        let now = Date()
        let personal = ClaudeProfileSnapshot(
            id: "p", label: "Personal",
            live: [ClaudeLiveSession(id: "p|s", profileID: "p", profileLabel: "Personal", project: "nootch-oc",
                                     started: now.addingTimeInterval(-134), lastActivity: now)],
            today: ClaudeUsageSummary(tokens: ClaudeTokens(input: 120_000, cacheWrite: 400_000, cacheRead: 12_000_000, output: 90_000),
                                      cost: 6.53, hasUnpriced: false, requests: 52),
            limits: [ClaudeLimitWindow(kind: .session, usedPercent: 72, resetsAt: now.addingTimeInterval(11_520), isEstimate: true),
                     ClaudeLimitWindow(kind: .weekly, usedPercent: 13, resetsAt: now.addingTimeInterval(432_000), isEstimate: true)])
        let work = ClaudeProfileSnapshot(
            id: "w", label: "Work", live: [],
            today: ClaudeUsageSummary(tokens: ClaudeTokens(input: 5_000, cacheWrite: 20_000, cacheRead: 300_000, output: 8_000),
                                      cost: 0.42, hasUnpriced: true, requests: 7),
            limits: [])
        return [personal, work]
    }

    /// The leftmost x, in points, holding a visible pixel; nil when nothing rendered. Drawn through a real
    /// `NSHostingView` because `ImageRenderer` leaves a `ScrollView` blank.
    private func leftmostVisiblePoint<V: View>(_ view: V, width: CGFloat, height: CGFloat) throws -> Double? {
        let host = NSHostingView(rootView: view.preferredColorScheme(.dark))
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let image = try XCTUnwrap(rep.cgImage)
        let pixelsPerPoint = Double(image.width) / Double(width)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                                              bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        for x in 0..<image.width {
            for y in 0..<image.height {
                let i = (y * image.width + x) * 4
                if max(pixels[i], pixels[i + 1], pixels[i + 2]) > 24 { return Double(x) / pixelsPerPoint }
            }
        }
        return nil
    }

    private func content(_ profiles: [ClaudeProfileSnapshot]) -> some View {
        ClaudeUsageWidgetContent(isLoaded: true, profiles: profiles)
            .frame(width: 168, height: 110, alignment: .topLeading)
            .background(Color.black)
    }

    func testContentKeepsAGutterFromTheScrollViewsClippedLeftEdge() throws {
        let left = try XCTUnwrap(leftmostVisiblePoint(content(profiles()), width: 168, height: 110), "the content should render something")
        XCTAssertGreaterThanOrEqual(left, 1.5, "content starts \(left)pt from the clip edge; glyphs and bars there get shaved")
    }

    func testEmptyStateStillRenders() throws {
        let empty = ClaudeUsageWidgetContent(isLoaded: true, profiles: [])
            .frame(width: 168, height: 110).background(Color.black)
        XCTAssertNotNil(try leftmostVisiblePoint(empty, width: 168, height: 110))
    }
}
