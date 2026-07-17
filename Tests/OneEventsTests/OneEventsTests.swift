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

private let alertPacket = """
{
  "objects": [
    {
      "type": "alert",
      "archive": "hosts/DEMOSERVER/MultimediaStorage.Alert/MultimediaStorage",
      "id": "F5A0401B-FC2D-4384-83DE-CA5E4139EBC0",
      "initiator": "9ffabb81-eae4-45d8-a2d0-356ce4e7aaf5",
      "initiator_type": "macro",
      "phase": "started",
      "source": "hosts/DEMOSERVER/DeviceIpint.5/SourceEndpoint.video:0:0",
      "state_macro": "raise_alert",
      "states": [
        {
          "type": "alert_state",
          "alert_id": "F5A0401B-FC2D-4384-83DE-CA5E4139EBC0",
          "id": "A63C73E2-12F9-406D-8E64-E7E018B6B4D8",
          "name": "hosts/DEMOSERVER/DeviceIpint.5/SourceEndpoint.video:0:0",
          "reviewer": "",
          "reviewer_type": "system",
          "severity": "unclassified",
          "state": "reaction",
          "priority": "AP_HIGH"
        }
      ],
      "timestamp": "20240801T095025.910497"
    }
  ]
}
"""

private let alertStatePacket = """
{
  "objects": [
    {
      "type": "alert_state",
      "alert_id": "F5A0401B-FC2D-4384-83DE-CA5E4139EBC0",
      "id": "e21cc8af-5386-4e50-a1e0-dbb3602bb7e3",
      "message": "",
      "name": "hosts/DEMOSERVER/DeviceIpint.5/SourceEndpoint.video:0:0",
      "reviewer": "root",
      "reviewer_type": "user",
      "severity": "alarm",
      "state": "closed",
      "priority": "AP_MAXIMUM"
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
    #expect(armUpdate.state.value == .arm)

    let objectActivated = try #require(try decodeFirst(objectActivatedPacket))
    let activation = try #require(try EventParsers.objectActivated(objectActivated))
    #expect(activation.isActivated)
    #expect(activation.objectIdExt.friendlyName == "Camera 1")

    let alertWire = try #require(try decodeFirst(alertPacket))
    let alert = try #require(try EventParsers.alert(alertWire))
    #expect(alert.id == "F5A0401B-FC2D-4384-83DE-CA5E4139EBC0")
    #expect(alert.initiatorType.value == .macro)
    #expect(alert.states.count == 1)
    #expect(alert.states[0].state.value == .reaction)
    #expect(alert.states[0].priority?.value == .high)

    let alertStateWire = try #require(try decodeFirst(alertStatePacket))
    let alertState = try #require(try EventParsers.alertState(alertStateWire))
    #expect(alertState.alertId == "F5A0401B-FC2D-4384-83DE-CA5E4139EBC0")
    #expect(alertState.state.value == .closed)
    #expect(alertState.severity.value == .alarm)
    #expect(alertState.reviewerType.value == .user)
}

@Test func dispatcherPublishesAlertHubs() async throws {
    let dispatcher = EventDispatcher()
    let alertStream = await dispatcher.alertEvents()
    let stateStream = await dispatcher.alertStateEvents()

    let alertWire = try #require(try decodeFirst(alertPacket))
    let stateWire = try #require(try decodeFirst(alertStatePacket))

    async let firstAlert: AlertEvent? = {
        for await value in alertStream { return value }
        return nil
    }()
    async let firstState: AlertStateEvent? = {
        for await value in stateStream { return value }
        return nil
    }()

    await dispatcher.dispatch(alertWire)
    await dispatcher.dispatch(stateWire)

    let alert = try #require(await firstAlert)
    let state = try #require(await firstState)
    #expect(alert.id == "F5A0401B-FC2D-4384-83DE-CA5E4139EBC0")
    #expect(state.state.value == .closed)
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
