//
//  Channel+ErrorTests.swift
//  SwiftPhoenixClientTests
//
//  Created by Jatinder Sidhu on 2022-10-18.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import XCTest
import Combine
@testable import SwiftPhoenixClient

extension ChannelTests {
    // onClose sets state to closed
    func testOnCloseSetsChannelStateClosed() async {
        do {
            let channel = await createJoinableTestChannel()
            try await channel.join()

            var state = await channel.state
            XCTAssertFalse(state == .closed)

            let expectation = expectation(description: "expected close response")
            channel
                .on(ChannelEvent.close)
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            await channel.trigger(event: ChannelEvent.close)
            await waitForExpectations(timeout: 3)
            state = await channel.state
            XCTAssert(state == .closed)
        } catch {
            XCTFail("testOnCloseSetsChannelStateClosed failed to join channel")
        }
    }

    // onClose resets the rejoin timer
    func testOnCloseResetsTimer() async {
        do {
            let channel = await createJoinableTestChannel()
            let mockRejoinTimer = TimeoutTimerMock()
            await channel.update(rejoinTimer: mockRejoinTimer)
            try await channel.join()

            var state = await channel.state
            XCTAssertFalse(state == .closed)

            let expectation = expectation(description: "expected close response")
            channel
                .on(ChannelEvent.close)
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            await channel.trigger(event: ChannelEvent.close)
            await waitForExpectations(timeout: 3)
            state = await channel.state
            XCTAssert(state == .closed)
            XCTAssert(mockRejoinTimer.resetCalled)
        } catch {
            XCTFail("testOnCloseSetsChannelStateClosed failed to join channel")
        }
    }

    // onClose removes self from socket
    func testOnCloseRemovesChannelFromSocket() async {
        do {
            let webSocket = URLSessionTransportMock()
            webSocket.readyState = .open
            let mockSocket = createTestChannelSocket(webSocket: webSocket)
            let channel = await mockSocket.channel("topic")
            try await channel.join()

            let expectation = expectation(description: "expected close response")
            channel
                .on(ChannelEvent.close)
                .debounce(for: 0.2, scheduler: DispatchQueue.global())
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            XCTAssert(mockSocket.channels.count == 1)
            await channel.trigger(event: ChannelEvent.close)
            await waitForExpectations(timeout: 3)

            XCTAssert(mockSocket.channels.isEmpty)
        } catch {
            XCTFail("testOnCloseSetsChannelStateClosed failed to join channel")
        }
    }

    // onClose pushes can not send
    func testOnClosePushesCanNotSend() async {
        do {
            let channel = await createJoinableTestChannel()
            try await channel.join()

            let expectation = expectation(description: "expected close response")
            channel
                .on(ChannelEvent.close)
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            await channel.trigger(event: ChannelEvent.close)
            await waitForExpectations(timeout: 3)

            let canPush = await channel.canPush
            XCTAssertFalse(canPush)
        } catch {
            XCTFail("testOnCloseSetsChannelStateClosed failed to join channel")
        }
    }
}

//        describe("on") {
//            beforeEach {
//                mockSocket.makeRefClosure = nil
//                mockSocket.makeRefReturnValue = kDefaultRef
//            }
//
//            it("sets up callback for event", closure: {
//                var onCallCount = 0
//
//                channel.trigger(event: "event", ref: kDefaultRef)
//                XCTAssert(onCallCount == 0))
//
//                channel.on("event", callback: { (_) in
//                    onCallCount += 1
//                })
//
//                channel.trigger(event: "event", ref: kDefaultRef)
//                XCTAssert(onCallCount == 1))
//            })
//
//            it("other event callbacks are ignored", closure: {
//                var onCallCount = 0
//                let ignoredOnCallCount = 0
//
//                channel.trigger(event: "event", ref: kDefaultRef)
//                XCTAssert(ignoredOnCallCount == 0))
//
//                channel.on("event", callback: { (_) in
//                    onCallCount += 1
//                })
//
//                channel.trigger(event: "event", ref: kDefaultRef)
//                XCTAssert(ignoredOnCallCount == 0))
//            })
//
//            it("generates unique refs for callbacks ", closure: {
//                let ref1 = channel.on("event1", callback: { _ in })
//                let ref2 = channel.on("event2", callback: { _ in })
//                XCTAssert(ref1).toNot(equal(ref2))
//                XCTAssert(ref1 + 1 == ref2))
//
//            })
//        }
//

//
//        describe("onError") {
//
//            var spySocket: SocketSpy!
//            var joinPush: Push!
//
//            beforeEach {
//                mockClient.readyState = .open
//                spySocket = SocketSpy(endPoint: "/socket",
//                                      transport: { _ in return mockClient })
//                spySocket.connect()
//
//                channel = Channel(topic: "topic", params: ["one": "two"], socket: spySocket)
//                joinPush = channel.joinPush
//
//                channel.join()
//                joinPush.trigger("ok", payload: [:])
//            }
//
//            it("does not trigger redundant errors during backoff", closure: {
//                // Spy the channel's Join Push
//                let mockPush = PushMock(channel: channel, event: "event")
//                channel.joinPush = mockPush
//
//                XCTAssert(mockPush.resendCalled).to(beFalse())
//                channel.trigger(event: ChannelEvent.error)
//
//                fakeClock.tick(1.0)
//                XCTAssert(mockPush.resendCalled).to(beTrue())
//                XCTAssert(mockPush.resendCallsCount == 1))
//
//                channel.trigger(event: "error")
//                fakeClock.tick(1.0)
//                XCTAssert(mockPush.resendCallsCount == 1))
//            })
//
//            describe("while joining") {
//
//                var mockPush: PushMock!
//
//                beforeEach {
//                    channel = Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
//
//                    // Spy the channel's Join Push
//                    mockPush = PushMock(channel: channel, event: "event")
//                    mockPush.ref = "10"
//                    channel.joinPush = mockPush
//                    channel.state = .joining
//                }
//
//                it("removes the joinPush message from send buffer") {
//                    channel.trigger(event: ChannelEvent.error)
//                    XCTAssert(mockSocket.removeFromSendBufferRefCalled).to(beTrue())
//                    XCTAssert(mockSocket.removeFromSendBufferRefReceivedRef == "10"))
//                }
//
//                it("resets the joinPush") {
//                    channel.trigger(event: ChannelEvent.error)
//                    XCTAssert(mockPush.resetCalled).to(beTrue())
//                }
//            }
//
//            it("sets channel state to .errored", closure: {
//                XCTAssert(channel.state).toNot(equal(.errored))
//
//                channel.trigger(event: ChannelEvent.error)
//                XCTAssert(channel.state == .errored))
//            })
//
//            it("tries to rejoin with backoff", closure: {
//                let mockRejoinTimer = TimeoutTimerMock()
//                channel.rejoinTimer = mockRejoinTimer
//
//                channel.trigger(event: ChannelEvent.error)
//                XCTAssert(mockRejoinTimer.scheduleTimeoutCalled).to(beTrue())
//            })
//
//            it("does not rejoin if channel leaving", closure: {
//                channel.state = .leaving
//
//                let mockPush = PushMock(channel: channel, event: "event")
//                channel.joinPush = mockPush
//
//                spySocket.onConnectionError(TestError.stub)
//
//                fakeClock.tick(1.0)
//                XCTAssert(mockPush.sendCallsCount == 0))
//
//                fakeClock.tick(2.0)
//                XCTAssert(mockPush.sendCallsCount == 0))
//
//                XCTAssert(channel.state == .leaving))
//            })
//
//            it("does nothing if channel is closed", closure: {
//                channel.state = .closed
//
//                let mockPush = PushMock(channel: channel, event: "event")
//                channel.joinPush = mockPush
//
//                spySocket.onConnectionError(TestError.stub)
//
//                fakeClock.tick(1.0)
//                XCTAssert(mockPush.sendCallsCount == 0))
//
//                fakeClock.tick(2.0)
//                XCTAssert(mockPush.sendCallsCount == 0))
//
//                XCTAssert(channel.state == .closed))
//            })
//
//            it("triggers additional callbacks", closure: {
//                var onErrorCallCount = 0
//                channel.onError({ (_) in onErrorCallCount += 1 })
//                joinPush.trigger("ok", payload: [:])
//
//                XCTAssert(channel.state == .joined))
//                XCTAssert(onErrorCallCount == 0))
//
//                channel.trigger(event: ChannelEvent.error)
//                XCTAssert(onErrorCallCount == 1))
//            })
//        }

extension ChannelTests {
    // state isClosed returns true if state is .closed
    func testStateIsClosed() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)

        await channel.update(state: .joined)
        var state = await channel.isClosed
        XCTAssertFalse(state)

        await channel.update(state: .closed)
        state = await channel.isClosed
        XCTAssert(state)
    }

    // state isErrored returns true if state is .errored
    func testStateIsErrored() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)

        await channel.update(state: .joined)
        var state = await channel.isErrored
        XCTAssertFalse(state)

        await channel.update(state: .errored)
        state = await channel.isErrored
        XCTAssert(state)
    }

    // state isJoined returns true if state is .joined
    func testStateIsJoined() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)

        await channel.update(state: .leaving)
        var state = await channel.isJoined
        XCTAssertFalse(state)

        await channel.update(state: .joined)
        state = await channel.isJoined
        XCTAssert(state)
    }

    // state isJoining returns true if state is .joining
    func testStateIsJoining() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)

        await channel.update(state: .joined)
        var state = await channel.isJoining
        XCTAssertFalse(state)

        await channel.update(state: .joining)
        state = await channel.isJoining
        XCTAssert(state)
    }

    // state isLeaving returns true if state is .leaving
    func testStateIsLeaving() async {
        let mockSocket = createTestChannelSocket()
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)

        await channel.update(state: .joining)
        var state = await channel.isLeaving
        XCTAssertFalse(state)

        await channel.update(state: .leaving)
        state = await channel.isLeaving
        XCTAssert(state)
    }
}
