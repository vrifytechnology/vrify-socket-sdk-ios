//
//  ChannelTests.swift
//  SwiftPhoenixClient
//
//  Created by Daniel Rees on 5/18/18.
//

 import XCTest
 import Combine
 @testable import SwiftPhoenixClient

class ChannelTests: XCTestCase {
    // Constants
    static let kDefaultRef = "1"
    static let kDefaultTimeout: TimeInterval = 10.0
    var cancellables = Set<AnyCancellable>()

    func createTestChannelSocket(timeoutTimer: TimeoutTimer = TimeoutTimerMock(),
                                 webSocket: URLSessionTransportProtocol = URLSessionTransportMock()) -> Socket {
        let socket = Socket(endPoint: "/socket", transport: { _ in webSocket })
        socket.reconnectAfter = { _ in return 10 }
        socket.reconnectTimer = timeoutTimer
        socket.skipHeartbeat = true
        // socket.makeRefReturnValue = ChannelTests.kDefaultRef
        socket.reconnectAfter = { tries -> TimeInterval in
            return tries > 3 ? 10 : [1, 2, 5, 10][tries - 1]
        }

        socket.rejoinAfter = Defaults.rejoinSteppedBackOff
        socket.connect()

        return socket
    }

    func createJoinableTestChannel(webSocket: URLSessionTransportMock = URLSessionTransportMock()) async -> Channel {
        webSocket.readyState = .open
        let mockSocket = createTestChannelSocket(webSocket: webSocket)
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
        // mockSocket.channelParamsReturnValue = channel
        return channel
    }
}

extension ChannelTests {
    // constructor sets defaults
    func testConstructorDefaults() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)

        let state = await channel.state
        XCTAssert(state == ChannelState.closed)
        XCTAssert(channel.topic == "topic")
        let params = await channel.params["one"] as? String
        XCTAssert(params == "two")
        let socket = await channel.socket
        XCTAssert(socket === mockSocket)
        let timeout = await channel.timeout
        XCTAssert(timeout == 10)
        let joinedOnce = await channel.joinedOnce
        XCTAssertFalse(joinedOnce)
        let joinPush = await channel.joinPush
        XCTAssertNotNil(joinPush)
        let pushBuffer = await channel.pushBuffer
        XCTAssert(pushBuffer.isEmpty)
    }

    // constructor set up joinPush with literal params
    func testConstructorParams() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
        let joinPush = await channel.joinPush

        XCTAssert(joinPush?.channel === channel)
        XCTAssert(joinPush?.payload["one"] as? String == "two")
        XCTAssert(joinPush?.event == "phx_join")
        XCTAssert(joinPush?.timeout == 10)
    }

    // constructor should not introduce any retain cycles
    func testChannelRetainCycles() async {
        let mockSocket = createTestChannelSocket()
        weak var weakChannel = await Channel(topic: "topic", params: ["one": 2], socket: mockSocket)
        XCTAssertNil(weakChannel)
    }
}

extension ChannelTests {
    // ToDo: Do we really need to support onMessage with the message publisher now accessible?
    //
    //        describe("onMessage") {
    //            it("returns message by default", closure: {
    //                let message = channel.onMessage(Message(ref: "original"))
    //                XCTAssert(message.ref == "original"))
    //            })
    //
    //            it("can be overridden", closure: {
    //                channel.onMessage = { _ in
    //                    return Message(ref: "modified")
    //                }
    //
    //                let message = channel.onMessage(Message(ref: "original"))
    //                XCTAssert(message.ref == "modified"))
    //            })
    //        }
}

extension ChannelTests {
    // updating join params can update join params
    func testCanUpdateJoinParams() async {
        let params: Payload = ["value": 1]
        let change: Payload = ["value": 2]

        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: params, socket: mockSocket)
        let joinPush = await channel.joinPush

        XCTAssert(joinPush?.channel === channel)
        XCTAssert(joinPush?.payload["value"] as? Int == 1)
        XCTAssert(joinPush?.event == ChannelEvent.join)
        XCTAssert(joinPush?.timeout == 10)

        await channel.update(params: change)

        XCTAssert(joinPush?.channel === channel)
        XCTAssert(joinPush?.payload["value"] as? Int == 2)
        let paramsValue = await channel.params["value"] as? Int
        XCTAssert(paramsValue == 2)
        XCTAssert(joinPush?.event == ChannelEvent.join)
        XCTAssert(joinPush?.timeout == 10)
    }
}

extension ChannelTests {
    // join sets state to joining
    func testChannelJoinSetsJoiningState() async {
        let channel = await createJoinableTestChannel()

        _ = try? await channel.join()
        let state = await channel.state
        XCTAssert(state == .joining)
    }

    // join sets joinedOnce to true
    func testChannelJoinSetsJoinedOnceToTrue() async {
        let channel = await createJoinableTestChannel()

        var joinedOnce = await channel.joinedOnce
        XCTAssertFalse(joinedOnce)

        _ = try? await channel.join()
        joinedOnce = await channel.joinedOnce
        XCTAssert(joinedOnce)
    }

    // join throws if attempting to join multiple times
    func testChannelJoinThrowsJoiningMultipleTimes() async {
        let channel = await createJoinableTestChannel()

        let expectation = expectation(description: "Expeecting a thrown error")
        do {
            try await channel.join()
            try await channel.join()
        } catch {
            expectation.fulfill()
        }

        await waitForExpectations(timeout: 3)
    }

    // join triggers socket push with channel params
    func testChannelJoinTriggerSocketPush() async {
        let mockWebSocket = URLSessionTransportMock()
        mockWebSocket.readyState = .open
        let mockSocket = SocketMock(endPoint: "/socket", transport: { _ in mockWebSocket })
        mockSocket.connect()
        mockSocket.makeRefReturnValue = ChannelTests.kDefaultRef
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
        _ = try? await channel.join()

        XCTAssert(mockSocket.pushCalled)

        let args = mockSocket.pushArguments
        XCTAssert(args?.topic == "topic")
        XCTAssert(args?.event == "phx_join")
        XCTAssert(args?.payload["one"] as? String == "two")
        XCTAssert(args?.ref == ChannelTests.kDefaultRef)
        let joinRef = await channel.joinRef
        XCTAssert(args?.joinRef == joinRef)
    }

    // join can set timeout on joinPush
    func testChannelJoinSetTimeoutOnJoinPush() async {
        let channel = await createJoinableTestChannel()
        let joinPush = await channel.joinPush
        XCTAssert(joinPush?.timeout == Defaults.timeoutInterval)

        let newTimeout: TimeInterval = 0.1
        _ = try? await channel.join(timeout: newTimeout)
        XCTAssert(joinPush?.timeout == newTimeout)
    }

    // join leaves existing duplicate topic on new join
    func testChannelJoinLeavesDuplicateTopics() async {
        let mockWebSocket = URLSessionTransportMock()
        mockWebSocket.readyState = .open
        let spySocket = SocketSpy(endPoint: "/socket", transport: { _ in mockWebSocket })
        let channel = await spySocket.channel("topic", params: ["one": "two"])

        await spySocket.onConnectionOpen()

        do {
            let expectation = expectation(description: "expected ok response")
            try await channel.join()
                .pushResponse
                .compactMap { $0 }
                .filter { $0.status == "ok" }
                .debounce(for: 0.2, scheduler: DispatchQueue.global()) // Debounce to allow Push to update Channel
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in
                    Task {
                        let newChannel = await spySocket.channel("topic")
                        var isJoined  = await channel.isJoined
                        XCTAssert(isJoined)
                        _ = try? await newChannel.join()

                        isJoined  = await channel.isJoined
                        XCTAssertFalse(isJoined)
                        expectation.fulfill()
                    }
                })
                .store(in: &cancellables)

            await channel.joinPush.trigger("ok", payload: [:])
            await Task.yield()
            await waitForExpectations(timeout: 3)
        } catch {
            XCTFail("testChannelJoinLeavesDuplicateTopics Join threw an error")
        }
    }
}

extension ChannelTests {
    // leave unsubscribes from server events
    func testChannelLeaveUnsubscribesFromServer() async {
        let mockWebSocket = URLSessionTransportMock()
        mockWebSocket.readyState = .open
        let mockSocket = SocketMock(endPoint: "/socket", transport: { _ in mockWebSocket })
        let channel = await mockSocket.channel("topic", params: ["one": "two"])

        await mockSocket.onConnectionOpen()

        mockSocket.makeRefClosure = nil
        mockSocket.makeRefReturnValue = ChannelTests.kDefaultRef

        let joinRef = await channel.joinRef
        await channel.leave(timeout: Defaults.timeoutInterval)

        XCTAssert(mockSocket.pushCalled)
        guard let args = mockSocket.pushArguments else {
            XCTFail("Missing socket push arguments")
            return
        }
        XCTAssert(args.topic == "topic")
        XCTAssert(args.event == "phx_leave")
        XCTAssert(args.payload.isEmpty)
        XCTAssert(args.joinRef == joinRef)
        XCTAssert(args.ref == ChannelTests.kDefaultRef)
    }

    // leave closes channel on 'ok' from server
    func testChannelLeaveRecievesOkFromServer() async {
        let mockWebSocket = URLSessionTransportMock()
        mockWebSocket.readyState = .open
        let mockSocket = Socket(endPoint: "/socket", transport: { _ in mockWebSocket })
        let channel = await mockSocket.channel("topic", params: ["one": "two"])

        do {
            try await channel.join().trigger("ok", payload: [:])

            let anotherChannel = await mockSocket.channel("another", params: ["three": "four"])
            let channels = await mockSocket.isolatedModel.channels
            XCTAssert(channels.count == 2)

            let leavePush = await channel.leave(timeout: Defaults.timeoutInterval)
            let expectation = expectation(description: "Leaving Channel and being removed from Socket")

            leavePush
                .pushResponse
                .compactMap { $0 }
                .filter { $0.status == "ok" }
                .debounce(for: 0.2, scheduler: DispatchQueue.global()) // Debounce to allow Push to update Channel
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in
                    expectation.fulfill()
                })
                .store(in: &cancellables)

            await leavePush.trigger("ok", payload: [:])
            await waitForExpectations(timeout: 3)

            let updatedChannels = await mockSocket.isolatedModel.channels

            XCTAssert(updatedChannels.count == 1)
            XCTAssert(updatedChannels.first === anotherChannel)
        } catch {
            XCTFail("testChannelLeaveRecievesOkFromServer failed to join")
        }
    }

}

extension ChannelTests {
    // isMember returns false if the message topic does not match the channel
    func testIsMemberReturnsFalse() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)

        let message = Message(topic: "other")
        let isMember = await channel.isMember(message)
        XCTAssertFalse(isMember)
    }

    // isMember returns true if topics match but the message doesn't have a join ref
    func testIsMemberReturnsTrueIfMessageHasNoJoinRef() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)

        let message = Message(topic: "topic", event: ChannelEvent.close, joinRef: nil)
        let isMember = await channel.isMember(message)
        XCTAssert(isMember)
    }

    // isMember returns true if topics and join refs match
    func testIsMemberReturnsTrueIfMessageHasJoinRefMatching() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
        await channel.joinPush.ref = "2"

        let message = Message(topic: "topic", event: ChannelEvent.close, joinRef: "2")
        let isMember = await channel.isMember(message)
        XCTAssert(isMember)
    }

    // isMember returns true if topics and join refs match but event is not lifecycle
    func testIsMemberReturnsTrueIfNonLigfeCycleMessageHasJoinRefMatching() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
        await channel.joinPush.ref = "2"

        let message = Message(topic: "topic", event: "event", joinRef: "2")
        let isMember = await channel.isMember(message)
        XCTAssert(isMember)
    }

    // isMember returns false topics match and is a lifecycle event but join refs do not match
    func testIsMemberReturnsFlaseIfNonLifeCycleMessageNoJoinRefMatches() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
        await channel.joinPush.ref = "2"

        let message = Message(topic: "topic", event: ChannelEvent.close, joinRef: "1")
        let isMember = await channel.isMember(message)
        XCTAssertFalse(isMember)
    }
}
