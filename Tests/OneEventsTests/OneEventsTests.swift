import Testing
import Foundation
import OneWireFormat
@testable import OneEvents

private let detectorPacket = """
{
  "objects": [
    {
      "event_type": "faceAppeared",
      "id": "88bd02ff-3a63-45f1-a21b-043d2eab1dac",
      "source": "hosts/DEMOSERVER/DeviceIpint.1/SourceEndpoint.video:0:0",
      "state": 1,
      "timestamp": "20250114T103757.359000",
      "type": "detector_event"
    }
  ]
}
"""

private let cameraArmPacket = """
{
  "objects": [
    {
      "id": "661e0226-fc00-4b29-bcbe-57ae32dde463",
      "source": "hosts/Demoserver/DeviceIpint.1/SourceEndpoint.video:0:0",
      "state": "CS_Arm",
      "timestamp": "20260403T123542.757638",
      "type": "cameraarmstateevent"
    }
  ]
}
"""

private let objectActivatedPacket = """
{
  "objects": [
    {
      "type": "ObjectActivatedEvent",
      "objectIdExt": {
        "accessPoint": "hosts/DESKTOP-21M7L0R/DeviceIpint.1/SourceEndpoint.video:0:0",
        "group": "",
        "friendlyName": "Camera 1"
      },
      "timestamp": "20260330T081832.379813",
      "isActivated": true,
      "nodeInfo": {
        "name": "DESKTOP-21M7L0R",
        "friendlyName": "DESKTOP-21M7L0R"
      },
      "guid": "4466cda7-6623-4273-bf40-ab097c9cc5ea"
    }
  ]
}
"""

private let unknownPacket = """
{
  "objects": [
    {
      "type": "future_event",
      "id": "future-1",
      "nested": { "value": 42 }
    }
  ]
}
"""

@Test func typedParsersDecodeKnownEvents() throws {
    let detector = try #require(try decodeFirst(detectorPacket))
    let detectorEvent = try #require(try EventParsers.detector(detector))
    #expect(detectorEvent.id == "88bd02ff-3a63-45f1-a21b-043d2eab1dac")
    #expect(detectorEvent.eventType == "faceAppeared")
    #expect(detectorEvent.phase == .began)

    let cameraArm = try #require(try decodeFirst(cameraArmPacket))
    let armUpdate = try #require(try EventParsers.cameraArm(cameraArm))
    #expect(armUpdate.state == .arm)

    let objectActivated = try #require(try decodeFirst(objectActivatedPacket))
    let activation = try #require(try EventParsers.objectActivated(objectActivated))
    #expect(activation.isActivated)
    #expect(activation.objectIdExt.friendlyName == "Camera 1")
}

@Test func unknownParserKeepsStructuredJSON() throws {
    let event = try #require(try decodeFirst(unknownPacket))
    let value = try EventParsers.unknownJSON(event)
    #expect(value != nil)
}

@Test func commandEncodingMatchesServerShape() throws {
    let subscription = EventSubscription(include: ["a", "b"], exclude: ["c"])
    let subscriptionJSON = try subscription.jsonFormatted()
    #expect(subscriptionJSON.contains("\"include\""))
    #expect(subscriptionJSON.contains("\"exclude\""))
    #expect(subscriptionJSON.contains("\"a\""))

    let token = UpdateToken(auth_token: "token")
    let tokenJSON = try token.jsonFormatted()
    #expect(tokenJSON.contains("\"method\" : \"update_token\""))
    #expect(tokenJSON.contains("\"auth_token\" : \"token\""))
}

@Test func dispatcherPublishesTypedAndUnknownStreams() async throws {
    let dispatcher = EventDispatcher()
    var detectorIterator = await dispatcher.detectorEvents().makeAsyncIterator()
    var unknownIterator = await dispatcher.unknownEvents().makeAsyncIterator()

    let detector = try #require(try decodeFirst(detectorPacket))
    let unknown = try #require(try decodeFirst(unknownPacket))

    await dispatcher.dispatch(detector)
    let receivedDetector = await detectorIterator.next()
    #expect(receivedDetector?.eventType == "faceAppeared")

    await dispatcher.dispatch(unknown)
    let receivedUnknown = await unknownIterator.next()
    #expect(receivedUnknown != nil)
}

@MainActor
@Test func eventFeedKeepsLatestDetectorEvents() {
    let feed = EventFeed(capacity: 2)
    feed.append(
        DetectorEvent(
            id: "1",
            type: EventType.detector.rawValue,
            eventType: "MotionDetected",
            source: "camera-1",
            state: DetectorEvent.Phase.happened.rawValue,
            timestamp: "20250114T103757.359000",
            rectangles: nil,
            plateFull: nil,
            listedInfo: nil
        )
    )
    feed.append(
        DetectorEvent(
            id: "2",
            type: EventType.detector.rawValue,
            eventType: "MotionDetected",
            source: "camera-1",
            state: DetectorEvent.Phase.ended.rawValue,
            timestamp: "20250114T103758.359000",
            rectangles: nil,
            plateFull: nil,
            listedInfo: nil
        )
    )
    feed.append(
        DetectorEvent(
            id: "3",
            type: EventType.detector.rawValue,
            eventType: "MotionDetected",
            source: "camera-1",
            state: DetectorEvent.Phase.began.rawValue,
            timestamp: "20250114T103759.359000",
            rectangles: nil,
            plateFull: nil,
            listedInfo: nil
        )
    )

    #expect(feed.events.map(\.id) == ["3", "1"])
}

private func decodeFirst(_ packet: String) throws -> OneWireFormat.WSString.Event? {
    let data = try #require(packet.data(using: .utf8))
    return try OneWireFormat.WSString.decodeEventsPack(from: data).first
}
