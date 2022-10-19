//
//  Channel+JoinPushTests.swift
//  SwiftPhoenixClientTests
//
//  Created by Jatinder Sidhu on 2022-10-18.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import XCTest
import Combine
@testable import SwiftPhoenixClient

extension ChannelTests {
    private func createPushTestChannel(webSocket: URLSessionTransportMock = URLSessionTransportMock(),
                                       socket: SocketMock? = nil) async -> Channel {
        webSocket.readyState = .open
        let mockSocket = socket ?? SocketMock(endPoint: "/socket", transport: { _ in webSocket })
        let channel = await mockSocket.channel("topic", params: ["one": "two"])

        mockSocket.onConnectionOpen()

        mockSocket.makeRefClosure = { String(mockSocket.makeRefCallsCount) }
        mockSocket.makeRefReturnValue = ChannelTests.kDefaultRef
        return channel
    }

    // canPush returns true when socket connected and channel joined
    func testCanPushReturnsTrueWhenSocketConnected() async {
        let channel = await createJoinableTestChannel()
        await channel.update(state: .joined)
        let canPush = await channel.canPush
        XCTAssert(canPush)
    }

    // canPush otherwise returns false
    func testCanPushIsFalse() async {
        let mockWebSocket = URLSessionTransportMock()
        let mockSocket = createTestChannelSocket(webSocket: mockWebSocket)
        let channel = await Channel(topic: "topic", params: ["one": "two"], socket: mockSocket)
        await channel.update(state: .joined)

        mockWebSocket.readyState = .closed
        var canPush = await channel.canPush
        XCTAssertFalse(canPush)

        await channel.update(state: .joining)
        mockWebSocket.readyState = .open
        canPush = await channel.canPush
        XCTAssertFalse(canPush)

        await channel.update(state: .joining)
        mockWebSocket.readyState = .closed
        canPush = await channel.canPush
        XCTAssertFalse(canPush)
    }

    // push sends push event when successfully joined
    func testChannelPushSendsPushEventWhenJoined() async {
        let mockWebSocket = URLSessionTransportMock()
        let mockSocket = SocketMock(endPoint: "/socket", transport: { _ in mockWebSocket })
        let channel = await createPushTestChannel(webSocket: mockWebSocket, socket: mockSocket)

        do {
            let expectation = expectation(description: "join expected ok response")
            expectation.expectedFulfillmentCount = 2

            let joinResponse = try await channel.join().pushResponse
            let push = try await channel.createPush("event", payload: ["foo": "bar"], timeout: Defaults.timeoutInterval)
            let responses = Publishers.Merge(joinResponse.compactMap { $0 }, push.pushResponse.compactMap { $0 })

            responses
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in
                    expectation.fulfill()
                })
                .store(in: &cancellables)

            await channel.joinPush.trigger("ok", payload: [:])
            try await channel.send(push)
            await push.trigger("ok", payload: [:])

            await Task.yield()
            await waitForExpectations(timeout: 3)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }

        XCTAssert(mockSocket.pushCalled)
        guard let args = mockSocket.pushArguments else {
            XCTFail("Missing socket push arguments")
            return
        }
        let joinRef = await channel.joinRef
        XCTAssert(args.topic == "topic")
        XCTAssert(args.event == "event")
        XCTAssert(args.payload["foo"] as? String == "bar")
        XCTAssert(args.joinRef == joinRef)
        XCTAssert(args.ref == String(mockSocket.makeRefCallsCount))
    }

    // push enqueues push event to be sent once join has succeeded + sends and empties channel's buffered pushEvents
    func testChannelPushEnqueuesAndSendsPushEventWhenJoined() async {
        let mockWebSocket = URLSessionTransportMock()
        let mockSocket = SocketMock(endPoint: "/socket", transport: { _ in mockWebSocket })
        let channel = await createPushTestChannel(webSocket: mockWebSocket, socket: mockSocket)

        do {
            let expectation = expectation(description: "join expected ok response")
            expectation.expectedFulfillmentCount = 2

            let joinResponse = try await channel.join().pushResponse
            let push = try await channel.createPush("event", payload: ["foo": "bar"], timeout: Defaults.timeoutInterval)
            var pushBuffer = await channel.pushBuffer
            XCTAssert(pushBuffer.isEmpty)
            let responses = Publishers.Merge(joinResponse.compactMap { $0 }, push.pushResponse.compactMap { $0 })

            responses
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in
                    expectation.fulfill()
                })
                .store(in: &cancellables)

            try await channel.send(push)
            pushBuffer = await channel.pushBuffer
            XCTAssert(pushBuffer.count == 1)
            await channel.joinPush.trigger("ok", payload: [:])
            await push.trigger("ok", payload: [:])

            await Task.yield()
            await waitForExpectations(timeout: 3)

            pushBuffer = await channel.pushBuffer
            XCTAssert(pushBuffer.isEmpty)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }

        XCTAssert(mockSocket.pushCalled)
        guard let args = mockSocket.pushArguments else {
            XCTFail("Missing socket push arguments")
            return
        }
        let joinRef = await channel.joinRef
        XCTAssert(args.topic == "topic")
        XCTAssert(args.event == "event")
        XCTAssert(args.payload["foo"] as? String == "bar")
        XCTAssert(args.joinRef == joinRef)
        XCTAssert(args.ref == String(mockSocket.makeRefCallsCount))
    }

    // push does not push if channel join times out
    func testNoPushOnChannelJoinTimeout() async {
        let mockWebSocket = URLSessionTransportMock()
        let mockSocket = SocketMock(endPoint: "/socket", transport: { _ in mockWebSocket })
        mockSocket.timeout = 0.01
        let channel = await createPushTestChannel(webSocket: mockWebSocket, socket: mockSocket)

        do {
            let expectation = expectation(description: "join expected ok response")
            expectation.expectedFulfillmentCount = 1

            let joinResponse = try await channel.join().pushResponse
            let push = try await channel.createPush("event", payload: ["foo": "bar"], timeout: Defaults.timeoutInterval)
            let responses = Publishers.Merge(joinResponse.compactMap { $0 }, push.pushResponse.compactMap { $0 })

            responses
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: {
                    switch $0 {
                    case .failure:
                        expectation.fulfill()
                    case .finished:
                        XCTFail("testNoPushOnChannelJoinTimeout did not timeout")
                    }
                },
                      receiveValue: { _ in })
                .store(in: &cancellables)

            try await channel.send(push)
            await Task.yield()
            await waitForExpectations(timeout: 3)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }
    }

    // push uses channel timeout by default
    func testPushUsesChannelTimeout() async {
        let channel = await createPushTestChannel()

        do {
            let joinPush = try await channel.join()
            XCTAssert(joinPush.timeout == Defaults.timeoutInterval)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }
    }

    // push accepts accepts timeout arg
    func testPushAcceptsTimeoutArg() async {
        let channel = await createPushTestChannel()

        do {
            let expectation = expectation(description: "push did not timeout")
            _ = try await channel.join()
            let push = try await channel.createPush("event", payload: ["foo": "bar"], timeout: 0.1)

            push.pushResponse.compactMap { $0 }
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: {
                    switch $0 {
                    case .failure:
                        expectation.fulfill()
                    case .finished:
                        XCTFail("testNoPushOnChannelJoinTimeout did not timeout")
                    }
                },
                      receiveValue: { _ in })
                .store(in: &cancellables)

            try await channel.send(push)
            await Task.yield()
            await waitForExpectations(timeout: 3)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }
    }

    // push does not time out after receiving 'ok'
    func testPushDoesNotTimeOutAfterOK() async {
        let channel = await createPushTestChannel()

        do {
            let expectation = expectation(description: "join expected ok response")
            expectation.expectedFulfillmentCount = 2

            let joinPush = try await channel.join()
            let push = try await channel.createPush("event", payload: ["foo": "bar"], timeout: 0.01)

            push.pushResponse.compactMap { $0 }
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            joinPush
                .pushResponse
                .compactMap { $0 }
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            await channel.joinPush.trigger("ok", payload: [:])
            try await channel.send(push)
            await push.trigger("ok", payload: [:])

            await Task.yield()
            await waitForExpectations(timeout: 3)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }
    }

    // push throws if channel has not been joined
    func testPushThrowsIfNoChannelJoined() async {
        let channel = await createPushTestChannel()
        do {
            _ = try await channel.createPush("event", payload: ["foo": "bar"], timeout: 0.01)
            XCTFail("Push failed to throw when pushing before a channel has been joined")
        } catch { }
    }
}

extension ChannelTests {
    // joinPush receives 'ok' and triggers receive(ok) callback after ok response
    func testJoinPushReceivesOk() async {
        let channel = await createPushTestChannel()

        do {
            let expectation = expectation(description: "join expected ok response")
            let joinPush = try await channel.join()

            joinPush
                .pushResponse
                .compactMap { $0 }
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            await channel.joinPush.trigger("ok", payload: [:])
            await Task.yield()
            await waitForExpectations(timeout: 3)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }
    }

    // joinPush sets receivedMessage and sets channel state to joined
    func testJoinPushReceivesMessageAndChannelStateIsJoined() async {
        let channel = await createPushTestChannel()

        do {
            let expectation = expectation(description: "join expected ok response")
            let joinPush = try await channel.join()

            XCTAssertNil(joinPush.pushResponse.value)

            joinPush
                .pushResponse
                .compactMap { $0 }
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            await channel.joinPush.trigger("ok", payload: ["a": "b"])
            await Task.yield()
            await waitForExpectations(timeout: 3)

            guard let message = joinPush.pushResponse.value else {
                XCTFail("No message received")
                return
            }
            XCTAssert(message.status == "ok")
            XCTAssert(message.payload["a"] as? String == "b")

            let state = await channel.state
            XCTAssert(state == .joined)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }
    }

    // joinPush resets channel rejoinTimer
    func testJoinPushReceivesResetsChannelRejoinTimer() async {
        let channel = await createPushTestChannel()
        let mockRejoinTimer = TimeoutTimerMock()
        await channel.update(rejoinTimer: mockRejoinTimer)

        do {
            let expectation = expectation(description: "join expected ok response")
            let joinPush = try await channel.join()

            XCTAssertNil(joinPush.pushResponse.value)

            joinPush
                .pushResponse
                .compactMap { $0 }
                .filter { $0.status == "ok" }
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in expectation.fulfill() })
                .store(in: &cancellables)

            await channel.joinPush.trigger("ok", payload: ["a": "b"])
            await Task.yield()
            await waitForExpectations(timeout: 3)

            // The time will reset twice since the socket has technically opened and reset the time once before join
            XCTAssert(mockRejoinTimer.resetCallsCount == 2)
        } catch {
            XCTFail("testChannelPushSendsPushEventWhenJoined Join threw an error")
        }
    }
}

//            describe("receives `error`", {
//                it("triggers receive('error') callback after error response", closure: {
//                    XCTAssert(channel.state == .joining))
//
//                    var errorCallsCount = 0
//                    joinPush.receive("error") { (_) in errorCallsCount += 1 }
//
//                    receiveError()
//                    joinPush.trigger("error", payload: [:])
//                    XCTAssert(errorCallsCount == 1))
//                })
//
//                it("triggers receive('error') callback if error response already received", closure: {
//                    receiveError()
//
//                    var errorCallsCount = 0
//                    joinPush.receive("error") { (_) in errorCallsCount += 1 }
//
//                    XCTAssert(errorCallsCount == 1))
//                })
//
//                it("does not trigger other receive callbacks after ok response", closure: {
//                    var receiveOkCallCount = 0
//                    var receiveTimeoutCallCount = 0
//                    var receiveErrorCallCount = 0
//                    joinPush
//                        .receive("ok") {_ in receiveOkCallCount += 1 }
//                        .receive("error", callback: { (_) in
//                            receiveErrorCallCount += 1
//                            channel.leave()
//                        })
//                        .receive("timeout") {_ in receiveTimeoutCallCount += 1 }
//
//                    receiveError()
//                    receivesTimeout()
//
//                    XCTAssert(receiveErrorCallCount == 1))
//                    XCTAssert(receiveOkCallCount == 0))
//                    XCTAssert(receiveTimeoutCallCount == 0))
//                })
//
//                it("clears timeoutTimer workItem", closure: {
//                    XCTAssert(joinPush.timeoutWorkItem).toNot(beNil())
//
//                    receiveError()
//                    XCTAssert(joinPush.timeoutWorkItem).to(beNil())
//                })
//
//                it("sets receivedMessage", closure: {
//                    XCTAssert(joinPush.receivedMessage).to(beNil())
//
//                    receiveError()
//                    XCTAssert(joinPush.receivedMessage).toNot(beNil())
//                    XCTAssert(joinPush.receivedMessage?.status == "error"))
//                    XCTAssert(joinPush.receivedMessage?.payload["a"] as? String == "b"))
//                })
//
//                it("removes channel binding", closure: {
//                    var bindings = getBindings("chan_reply_3")
//                    XCTAssert(bindings).to(haveCount(1))
//
//                    receiveError()
//                    bindings = getBindings("chan_reply_3")
//                    XCTAssert(bindings).to(haveCount(0))
//                })
//
//                it("does not sets channel state to joined", closure: {
//                    receiveError()
//                    XCTAssert(channel.state).toNot(equal(.joined))
//                })
//
//                it("does not trigger channel's buffered pushEvents", closure: {
//                    let mockPush = PushMock(channel: channel, event: "new:msg")
//                    channel.pushBuffer.append(mockPush)
//
//                    receiveError()
//                    XCTAssert(mockPush.sendCalled).to(beFalse())
//                    XCTAssert(channel.pushBuffer).to(haveCount(1))
//                })
//            })
//        }
