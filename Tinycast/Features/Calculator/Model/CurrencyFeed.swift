import Foundation

/// Decodes Coinbase's exchange-rate feed into one snapshot. Pure; the store does the IO.
enum CurrencyFeed {
    /// Every rate is units of `currency` per one base, as a decimal string, fiat and coins alike.
    private struct Payload: Decodable {
        struct Body: Decodable {
            let currency: String
            let rates: [String: String]
        }

        let data: Body
    }

    /// One units-per-base table; `complete` is false when no coin was priced.
    static func snapshot(_ feed: Data, now: Date) throws -> (rates: CurrencyRates, complete: Bool) {
        let body = try JSONDecoder().decode(Payload.self, from: feed).data
        let base = body.currency
        guard base.count == 3 else { throw URLError(.cannotParseResponse) }

        var rates: [String: Double] = [:]
        rates.reserveCapacity(body.rates.count + 1)
        for (code, text) in body.rates {
            guard let rate = Double(text), usable(rate) else { continue }
            rates[code] = rate
        }
        rates[base] = 1
        guard rates.count > 1 else { throw URLError(.cannotParseResponse) }

        let snapshot = CurrencyRates(base: base, rates: rates, fetchedAt: now)
        return (snapshot, pricesCoins(snapshot))
    }

    /// Only whole snapshots are persisted, so a cached one pricing no coin predates them entirely.
    static func pricesCoins(_ snapshot: CurrencyRates) -> Bool {
        CalcCurrency.cryptoCodes.contains { snapshot.rates[$0] != nil }
    }

    private static func usable(_ rate: Double) -> Bool {
        rate > 0 && rate.isFinite
    }
}
