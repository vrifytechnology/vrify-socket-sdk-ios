//
//  Channel+TimeoutTests.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-18.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import XCTest
import Combine
@testable import SwiftPhoenixClient

//
//    func createTestChannel() -> Channel {
//        let fakeClock = FakeTimerQueue()
//        TimerQueue.main = fakeClock
//
//        let mockClient = URLSessionTransportMock()
//        let mockSocket = SocketMock(endPoint: "/socket", transport: { _ in
//            // swiftlint:disable:next force_cast
//            URLSessionTransportMock() as! any URLSessionTransportProtocol
//        })
//
//        mockSocket.connection = mockClient
//        mockSocket.timeout = ChannelTests.kDefaultTimeout
//        mockSocket.makeRefReturnValue = ChannelTests.kDefaultRef
//        mockSocket.reconnectAfter = { tries -> TimeInterval in
//            return tries > 3 ? 10 : [1, 2, 5, 10][tries - 1]
//        }
//
//        mockSocket.rejoinAfter = Defaults.rejoinSteppedBackOff
//
//        let channel = Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
//        mockSocket.channelParamsReturnValue = channel
//        return channel
//    }
//
//    // swiftlint:disable:next function_body_length
//    override func spec() {
//
//        // Mocks
//        var mockClient: URLSessionTransportMock!
//        var mockSocket: SocketMock!
//
//        // Clock
//        var fakeClock: FakeTimerQueue!
//
//        // UUT
//        var channel: Channel!
//
//        /// Utility method to easily filter the bindings for a channel by their event
//        func getBindings(_ event: String) -> [Binding]? {
//            return channel.bindingsDel.filter({ $0.event == event })
//        }
//
//        beforeEach {
//            // Any TimeoutTimer that is created will receive the fake clock
//            // when scheduling work items
//
//        }
//
//        afterEach {
//            fakeClock.reset()
//        }

extension ChannelTests {
    // timeout behavior succeeds before timeout
    func testPushSucceedsBeforeTimeout() async {
        let fakeClock = FakeTimerQueue()
        TimerQueue.main = fakeClock
        let mockWebSocket = URLSessionTransportMock()
        mockWebSocket.readyState = .closed
        let spySocket = SocketSpy(endPoint: "/socket", transport: { _ in mockWebSocket })
        let channel = await spySocket.channel("topic", params: ["one": "two"])

        spySocket.connect()
        await spySocket.onConnectionOpen()

        do {
            let joinPush = try await channel.join()
            XCTAssertNotNil(spySocket.pushCalled)
            let timeout = await channel.timeout
            XCTAssert(timeout == 10.0)

            fakeClock.tick(0.100)

            let expectation = expectation(description: "ok was not triggered")

            guard let refEvent = joinPush.refEvent else {
                XCTFail("Missing Ref Event")
                return
            }

            channel
                .on(refEvent)
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            await joinPush.trigger("ok", payload: [:])
            await Task.yield()
            await waitForExpectations(timeout: 3)

            let state = await channel.state
            XCTAssert(state == .joined)

            fakeClock.tick(timeout)
            XCTAssert(spySocket.pushCallCount == 1)
        } catch {
            XCTFail("pushSucceedsBeforeTimeout Join threw an error")
        }
    }

    // timeout behavior

    // timeout behavior

    // timeout behavior

    // timeout behavior

    // timeout behavior
}

//        describe("timeout behavior") {
//
//            var spySocket: SocketSpy!
//            var joinPush: Push!
//            var timeout: TimeInterval!
//
//            beforeEach {
//                mockClient.readyState = .closed
//                let transport: ((URL) -> PhoenixTransport) = { _ in return mockClient }
//                spySocket = SocketSpy(endPoint: "/socket", transport: transport)
//                channel = Channel(topic: "topic", params: ["one": "two"], socket: spySocket)
//
//                joinPush = channel.joinPush
//                timeout = joinPush.timeout
//            }

//            it("retries with backoff after timeout", closure: {
//                spySocket.connect()
//                receiveSocketOpen()
//
//                var timeoutCallCount = 0
//                channel.join().receive("timeout", callback: { (_) in
//                    timeoutCallCount += 1
//                })
//
//                XCTAssert(spySocket.pushCallCount == 1))
//                XCTAssert(spySocket.pushArgs[1]?.event == "phx_join"))
//                XCTAssert(timeoutCallCount == 0))
//
//                fakeClock.tick(timeout) // leave pushed to server
//                XCTAssert(spySocket.pushCallCount == 2))
//                XCTAssert(spySocket.pushArgs[2]?.event == "phx_leave"))
//                XCTAssert(timeoutCallCount == 1))
//
//                fakeClock.tick(timeout + 1) // rejoin
//                XCTAssert(spySocket.pushCallCount == 4))
//                XCTAssert(spySocket.pushArgs[3]?.event == "phx_join"))
//                XCTAssert(spySocket.pushArgs[4]?.event == "phx_leave"))
//                XCTAssert(timeoutCallCount == 2))
//
//                fakeClock.tick(10)
//                joinPush.trigger("ok", payload: [:])
//                XCTAssert(spySocket.pushCallCount == 5))
//                XCTAssert(spySocket.pushArgs[5]?.event == "phx_join"))
//                XCTAssert(channel.state == .joined))
//            })
//
//            it("with socket and join delay", closure: {
//                channel.join()
//                XCTAssert(spySocket.pushCallCount == 1))
//
//                // Open the socket after a delay
//                fakeClock.tick(9.0)
//                XCTAssert(spySocket.pushCallCount == 1))
//
//                // join request returns between timeouts
//                fakeClock.tick(1.0)
//                spySocket.connect()
//
//                XCTAssert(channel.state == .errored))
//                receiveSocketOpen()
//                joinPush.trigger("ok", payload: [:])
//
//                fakeClock.tick(1.0)
//                XCTAssert(channel.state == .joined))
//                XCTAssert(spySocket.pushCallCount == 3))
//            })
//
//            it("with socket delay only", closure: {
//                channel.join()
//                XCTAssert(channel.state == .joining))
//
//                // connect socket after a delay
//                fakeClock.tick(6.0)
//                spySocket.connect()
//
//                // open Socket after delay
//                fakeClock.tick(5.0)
//                receiveSocketOpen()
//                joinPush.trigger("ok", payload: [:])
//
//                joinPush.trigger("ok", payload: [:])
//                XCTAssert(channel.state == .joined))
//            })
//        }
//

//            describe("receives 'timeout'", {
//                it("sets channel state to errored", closure: {
//                    var timeoutReceived = false
//                    joinPush.receive("timeout", callback: { (_) in
//                        timeoutReceived = true
//                        XCTAssert(channel.state == .errored))
//                    })
//
//                    receivesTimeout()
//                    XCTAssert(timeoutReceived).to(beTrue())
//                })
//
//                it("triggers receive('timeout') callback after ok response", closure: {
//                    var receiveTimeoutCallCount = 0
//                    joinPush.receive("timeout", callback: { (_) in
//                        receiveTimeoutCallCount += 1
//                    })
//
//                    receivesTimeout()
//                    XCTAssert(receiveTimeoutCallCount == 1))
//                })
//
//                it("does not trigger other receive callbacks after timeout response", closure: {
//                    var receiveOkCallCount = 0
//                    var receiveErrorCallCount = 0
//                    var timeoutReceived = false
//
//                    joinPush
//                        .receive("ok") {_ in receiveOkCallCount += 1 }
//                        .receive("error") {_ in receiveErrorCallCount += 1 }
//                        .receive("timeout", callback: { (_) in
//                            XCTAssert(receiveOkCallCount == 0))
//                            XCTAssert(receiveErrorCallCount == 0))
//                            timeoutReceived = true
//                        })
//
//                    receivesTimeout()
//                    receivesOk()
//
//                    XCTAssert(timeoutReceived).to(beTrue())
//                })
//
//                it("schedules rejoinTimer timeout", closure: {
//                    let mockRejoinTimer = TimeoutTimerMock()
//                    channel.rejoinTimer = mockRejoinTimer
//
//                    receivesTimeout()
//                    XCTAssert(mockRejoinTimer.scheduleTimeoutCalled).to(beTrue())
//                })
//            })
