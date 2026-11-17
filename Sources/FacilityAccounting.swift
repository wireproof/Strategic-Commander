import Foundation

enum FacilityAccounting {
    static let factoryPrice = 200
    static let labPrice = 250

    static func costs(existing: [Int]?, count: Int, home: Bool, research: Bool) -> [Int] {
        let price = research ? labPrice : factoryPrice
        if let existing = existing {
            let kept = Array(existing.prefix(count))
            return kept + Array(repeating: price, count: max(0, count - kept.count))
        }
        // Older saves did not record prices. Starting home factories were free;
        // other facilities used the original fixed construction price.
        return (0..<count).map { !research && home && $0 < 2 ? 0 : price }
    }

    static func sold(_ costs: [Int], index: Int) -> (remaining: [Int], refund: Int)? {
        guard costs.indices.contains(index) else { return nil }
        var remaining = costs
        let refund = remaining.remove(at: index)
        return (remaining, refund)
    }
}
