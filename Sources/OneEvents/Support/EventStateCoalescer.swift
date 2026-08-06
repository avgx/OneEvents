import Foundation

/// Coalesces keyed state updates into a single flush every ``flushIntervalNanoseconds``.
///
/// The timer starts on the first pending item in a batch and is **not** restarted
/// when more items arrive (fixed window from the first enqueue).
@MainActor
final class EventStateCoalescer<Value: Equatable> {
    private var pending: [AccessPoint: Value] = [:]
    private var flushTask: Task<Void, Never>?
    private let flushIntervalNanoseconds: UInt64
    private let onFlush: (_ batch: [AccessPoint: Value]) -> Void

    init(
        flushIntervalNanoseconds: UInt64 = 500_000_000,
        onFlush: @escaping (_ batch: [AccessPoint: Value]) -> Void
    ) {
        self.flushIntervalNanoseconds = flushIntervalNanoseconds
        self.onFlush = onFlush
    }

    /// Enqueues `value` for `key` if it differs from the current published value
    /// and from any already-pending value for that key.
    func enqueue(key: AccessPoint, value: Value, current: Value?) {
        if let pendingValue = pending[key], pendingValue == value {
            return
        }
        if pending[key] == nil, current == value {
            return
        }
        let shouldSchedule = pending.isEmpty
        pending[key] = value
        if shouldSchedule {
            scheduleFlush()
        }
    }

    func cancel() {
        flushTask?.cancel()
        flushTask = nil
        pending.removeAll()
    }

    /// Flushes immediately. Primarily useful for deterministic tests and shutdown.
    func flushNow() {
        flushTask?.cancel()
        flushTask = nil
        flush()
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: flushIntervalNanoseconds)
            guard !Task.isCancelled else { return }
            self.flushTask = nil
            self.flush()
        }
    }

    private func flush() {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        onFlush(batch)
    }
}

func changedStateBatch<Value: Equatable>(
    _ batch: [AccessPoint: Value],
    comparedTo states: [AccessPoint: Value]
) -> [(key: AccessPoint, value: Value)] {
    batch
        .filter { states[$0.key] != $0.value }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, value: $0.value) }
}

func stateBatchLogMessage<Value>(
    kind: String,
    changes: [(key: AccessPoint, value: Value)],
    valueLabel: (Value) -> String
) -> String {
    guard changes.count != 1 else {
        let change = changes[0]
        return "\(change.key) \(kind)=\(valueLabel(change.value))"
    }

    var counts: [String: Int] = [:]
    for change in changes {
        counts[valueLabel(change.value), default: 0] += 1
    }
    let breakdown = counts
        .sorted { $0.key < $1.key }
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: " ")
    let samples = changes.prefix(3)
        .map { "\($0.key) \(kind)=\(valueLabel($0.value))" }
        .joined(separator: ", ")
    return "\(kind) changed=\(changes.count) \(breakdown) samples=\(samples)"
}
