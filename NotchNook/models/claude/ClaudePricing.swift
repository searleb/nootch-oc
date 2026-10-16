import Foundation

/// API list prices, US dollars per million tokens. Used only to put a rough
/// value on usage; unknown models are left unpriced rather than guessed.
/// Long-context surcharges and fast-mode multipliers are not modelled.
enum ClaudePricing {
    struct Rate: Equatable {
        let input: Double
        let output: Double
        let cacheRead: Double
        let cacheWrite: Double
        let cacheWriteLong: Double
    }

    /// Longest matching id prefix wins, so `claude-opus-5-5` beats `claude-opus-5`.
    private static let table: [(id: String, rate: Rate)] = {
        func r(_ i: Double, _ o: Double, _ cr: Double, _ cw: Double, _ cwl: Double) -> Rate {
            Rate(input: i, output: o, cacheRead: cr, cacheWrite: cw, cacheWriteLong: cwl)
        }
        let rows: [(String, Rate)] = [
            ("claude-fable-5-1", r(10, 50, 0.25, 12.5, 20)), ("claude-fable-5", r(10, 50, 1, 12.5, 20)),
            ("claude-mythos-5-1", r(10, 50, 0.25, 12.5, 20)), ("claude-mythos-5", r(10, 50, 1, 12.5, 20)),
            ("claude-mythos-preview", r(25, 125, 2.5, 31.25, 50)),
            ("claude-opus-5-5", r(4, 20, 0.2, 5, 8)), ("claude-opus-5", r(5, 25, 0.5, 6.25, 10)),
            ("claude-opus-4-8", r(5, 25, 0.5, 6.25, 10)), ("claude-opus-4-7", r(5, 25, 0.5, 6.25, 10)),
            ("claude-opus-4-6", r(5, 25, 0.5, 6.25, 10)), ("claude-opus-4-5", r(5, 25, 0.5, 6.25, 10)),
            ("claude-opus-4-1", r(15, 75, 1.5, 18.75, 30)), ("claude-opus-4", r(15, 75, 1.5, 18.75, 30)),
            ("claude-sonnet-5-5", r(2, 10, 0.1, 2.5, 4)), ("claude-sonnet-5", r(2, 10, 0.2, 2.5, 4)),
            ("claude-sonnet-4-6", r(3, 15, 0.3, 3.75, 6)), ("claude-sonnet-4-5", r(3, 15, 0.3, 3.75, 6)),
            ("claude-sonnet-4", r(3, 15, 0.3, 3.75, 6)),
            ("claude-3-7-sonnet", r(3, 15, 0.3, 3.75, 6)), ("claude-3-5-sonnet", r(3, 15, 0.3, 3.75, 6)),
            ("claude-haiku-5-5", r(0.1, 0.5, 0.01, 0.125, 0.2)), ("claude-haiku-4-5", r(1, 5, 0.1, 1.25, 2)),
            ("claude-3-5-haiku", r(0.8, 4, 0.08, 1, 1.6)), ("claude-3-haiku", r(0.25, 1.25, 0.03, 0.3, 0.5)),
            ("claude-3-opus", r(15, 75, 1.5, 18.75, 30)),
        ]
        return rows.map { (id: $0.0, rate: $0.1) }.sorted { $0.id.count > $1.id.count }
    }()

    static func rate(for model: String) -> Rate? {
        table.first { model.hasPrefix($0.id) }?.rate
    }

    /// Nil when the model has no known price.
    static func cost(_ tokens: ClaudeTokens, longCacheWrite: Int, model: String) -> Double? {
        guard let rate = rate(for: model) else { return nil }
        let long = min(max(longCacheWrite, 0), tokens.cacheWrite)
        let short = tokens.cacheWrite - long
        let total = Double(tokens.input) * rate.input
            + Double(tokens.output) * rate.output
            + Double(tokens.cacheRead) * rate.cacheRead
            + Double(short) * rate.cacheWrite
            + Double(long) * rate.cacheWriteLong
        return total / 1_000_000
    }
}
