import Combine
import Testing
@testable import OneEvents

@MainActor
@Test func eventStateCoalescerKeepsLatestValuePerKey() {
    var flushed: [[AccessPoint: Int]] = []
    let coalescer = EventStateCoalescer<Int>(
        flushIntervalNanoseconds: .max,
        onFlush: { flushed.append($0) }
    )

    coalescer.enqueue(key: "camera-1", value: 1, current: nil)
    coalescer.enqueue(key: "camera-1", value: 2, current: nil)
    coalescer.enqueue(key: "camera-2", value: 3, current: 3)
    coalescer.flushNow()

    #expect(flushed.count == 1)
    #expect(flushed[0] == ["camera-1": 2])
}

@MainActor
@Test func cameraArmSeedPublishesOnceForWholeBatch() {
    let manager = CameraArmManager()
    var publications = 0
    let observation = manager.objectWillChange.sink {
        publications += 1
    }

    manager.seedInitialStates([
        "camera-1": .arm,
        "camera-2": .disarm,
        "camera-3": .arm,
    ])

    #expect(publications == 1)
    #expect(manager.states.count == 3)
    withExtendedLifetime(observation) {}
}

@Test func stateBatchSummaryIsStableAndBounded() {
    let changes = [
        (key: "camera-3", value: "off"),
        (key: "camera-1", value: "on"),
        (key: "camera-2", value: "on"),
        (key: "camera-4", value: "off"),
    ]

    let message = stateBatchLogMessage(
        kind: "record",
        changes: changes,
        valueLabel: { $0 }
    )

    #expect(message.contains("record changed=4"))
    #expect(message.contains("off=2"))
    #expect(message.contains("on=2"))
    #expect(!message.contains("camera-4 record=off"))
}
