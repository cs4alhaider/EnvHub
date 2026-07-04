import Foundation

/// One key in a side-by-side comparison of two environments.
public struct EnvDiffEntry: Sendable, Hashable, Identifiable {
    public enum State: String, Sendable, Hashable {
        case same
        case different
        case leftOnly
        case rightOnly
    }

    public var key: String
    public var leftValue: String?
    public var rightValue: String?
    public var state: State

    public var id: String { key }

    public init(key: String, leftValue: String?, rightValue: String?, state: State) {
        self.key = key
        self.leftValue = leftValue
        self.rightValue = rightValue
        self.state = state
    }
}

/// Computes a side-by-side diff of two environments' variables. Read-only.
public enum EnvDiff {
    /// Compare two variable lists. On duplicate keys within a side, the last value wins
    /// (matching typical `.env` "last assignment wins" semantics). Results are sorted
    /// by key.
    public static func compare(left: [EnvVar], right: [EnvVar]) -> [EnvDiffEntry] {
        var leftMap: [String: String] = [:]
        for v in left { leftMap[v.key] = v.value }
        var rightMap: [String: String] = [:]
        for v in right { rightMap[v.key] = v.value }

        let keys = Set(leftMap.keys).union(rightMap.keys).sorted()
        return keys.map { key in
            let l = leftMap[key]
            let r = rightMap[key]
            let state: EnvDiffEntry.State
            switch (l, r) {
            case (nil, _): state = .rightOnly
            case (_, nil): state = .leftOnly
            default: state = (l == r) ? .same : .different
            }
            return EnvDiffEntry(key: key, leftValue: l, rightValue: r, state: state)
        }
    }

    /// Summary counts for a computed diff.
    public static func summary(_ entries: [EnvDiffEntry]) -> (same: Int, different: Int, leftOnly: Int, rightOnly: Int) {
        var s = 0, d = 0, l = 0, r = 0
        for e in entries {
            switch e.state {
            case .same: s += 1
            case .different: d += 1
            case .leftOnly: l += 1
            case .rightOnly: r += 1
            }
        }
        return (s, d, l, r)
    }
}
