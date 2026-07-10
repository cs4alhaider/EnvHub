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

/// One key-level change between a saved file and pending edits (the save review).
/// A `.modified` change may carry a value edit, a comment edit, or both — check
/// `valueChanged` / `commentChanged`.
public struct EnvChange: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable {
        case added
        case removed
        case modified
    }

    public var kind: Kind
    public var key: String
    public var oldValue: String?
    public var newValue: String?
    public var oldComment: String?
    public var newComment: String?

    /// Keys are unique within one change set (duplicates collapse last-wins).
    public var id: String { key }

    public var valueChanged: Bool { oldValue != newValue }
    public var commentChanged: Bool { oldComment != newComment }

    public init(
        kind: Kind,
        key: String,
        oldValue: String? = nil,
        newValue: String? = nil,
        oldComment: String? = nil,
        newComment: String? = nil
    ) {
        self.kind = kind
        self.key = key
        self.oldValue = oldValue
        self.newValue = newValue
        self.oldComment = oldComment
        self.newComment = newComment
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

    /// Key-level changes from `old` to `new` — what the save-review sheet shows.
    /// Duplicate keys collapse last-wins (matching `compare`); rows with empty keys
    /// are ignored. Added and modified keys keep the new list's order; removed keys
    /// follow in the old list's order.
    public static func changes(from old: [EnvVar], to new: [EnvVar]) -> [EnvChange] {
        var oldByKey: [String: EnvVar] = [:]
        for v in old where !v.key.isEmpty { oldByKey[v.key] = v }
        var newByKey: [String: EnvVar] = [:]
        for v in new where !v.key.isEmpty { newByKey[v.key] = v }

        var changes: [EnvChange] = []
        var seen: Set<String> = []
        for v in new where !v.key.isEmpty && !seen.contains(v.key) {
            seen.insert(v.key)
            guard let current = newByKey[v.key] else { continue }
            if let previous = oldByKey[v.key] {
                if previous.value != current.value || previous.comment != current.comment {
                    changes.append(EnvChange(
                        kind: .modified, key: v.key,
                        oldValue: previous.value, newValue: current.value,
                        oldComment: previous.comment, newComment: current.comment
                    ))
                }
            } else {
                changes.append(EnvChange(
                    kind: .added, key: v.key,
                    newValue: current.value, newComment: current.comment
                ))
            }
        }
        for v in old where !v.key.isEmpty && newByKey[v.key] == nil && !seen.contains(v.key) {
            seen.insert(v.key)
            let previous = oldByKey[v.key]!
            changes.append(EnvChange(
                kind: .removed, key: v.key,
                oldValue: previous.value, oldComment: previous.comment
            ))
        }
        return changes
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
