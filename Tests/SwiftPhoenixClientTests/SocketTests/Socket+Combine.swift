//
//  Socket+Combine.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-17.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import XCTest
import Foundation
import Combine
@testable import SwiftPhoenixClient

extension SocketTests {
    private func createTimeoutableSocket(timeoutTimer: TimeoutTimer = TimeoutTimerMock(),
                                         webSocket: URLSessionTransportMock = URLSessionTransportMock()) -> Socket {
        let socket = Socket(endPoint: "/socket", transport: { _ in webSocket })
        socket.reconnectAfter = { _ in return 10 }
        socket.reconnectTimer = timeoutTimer
        socket.skipHeartbeat = true

        webSocket.readyState = .open
        socket.connect()
        return socket
    }

    // onConnectionOpen flushes the send buffer
    func testOnConnectionOpenSendBufferFlushes() {
        let socket = createTimeoutableSocket()

        var oneCalled = 0
        socket.sendBuffer.append(("0", { oneCalled += 1 }))

        socket.onConnectionOpen()
        XCTAssert(oneCalled == 1)
        XCTAssert(socket.sendBuffer.isEmpty)
    }

    // onConnectionOpen resets reconnectTimer
    func testOnConnectionResetsReconnectTimer() {
        let mockTimeoutTimer = TimeoutTimerMock()
        let socket = createTimeoutableSocket(timeoutTimer: mockTimeoutTimer)
        socket.onConnectionOpen()
        XCTAssert(mockTimeoutTimer.resetCalled)
    }

    // onConnectionOpen triggers onOpen callbacks
    func testOnConnectionOpenCallbacks() {
        let socket = createTimeoutableSocket()

        var oneCalled = 0
        socket.socketOpened
            .sink { oneCalled += 1 }
            .store(in: &cancellables)

        var twoCalled = 0
        socket.socketOpened
            .sink { twoCalled += 1 }
            .store(in: &cancellables)

        var threeCalled = 0
        socket.socketClosed
            .sink { threeCalled += 1 }
            .store(in: &cancellables)

        socket.onConnectionOpen()
        XCTAssert(oneCalled == 1)
        XCTAssert(twoCalled == 1)
        XCTAssert(threeCalled == 0)
    }
}

extension SocketTests {
    private func createClosableSocket(timeoutTimer: TimeoutTimer = TimeoutTimerMock(),
                                      webSocket: URLSessionTransportMock = URLSessionTransportMock()) -> Socket {
        let socket = Socket(endPoint: "/socket", transport: { _ in webSocket })
//        socket.reconnectAfter = { _ in return 10 }
        socket.reconnectTimer = timeoutTimer
//        socket.skipHeartbeat = true
        return socket
    }

    // onConnectionClosed schedules reconnectTimer timeout if normal close
    func testOnNormalCloseScheduleReconnect() async {
        let mockTimeoutTimer = TimeoutTimerMock()
        let socket = createClosableSocket(timeoutTimer: mockTimeoutTimer)

        await socket.onConnectionClosed(code: Socket.CloseCode.normal.rawValue)
        XCTAssert(mockTimeoutTimer.scheduleTimeoutCalled)
    }

    // onConnectionClosed does not schedule reconnectTimer timeout if normal close after explicit disconnect
    func testOnExplicitCloseDoesNotScheduleReconnect() async {
        let mockTimeoutTimer = TimeoutTimerMock()
        let socket = createClosableSocket(timeoutTimer: mockTimeoutTimer)

        socket.disconnect()
        XCTAssertFalse(mockTimeoutTimer.scheduleTimeoutCalled)
    }

    // onConnectionClosed schedules reconnectTimer timeout if not normal close
    func testOnNotNormalCloseSchedulesReconnect() async {
        let mockTimeoutTimer = TimeoutTimerMock()
        let socket = createClosableSocket(timeoutTimer: mockTimeoutTimer)

        await socket.onConnectionClosed(code: 1001)
        XCTAssert(mockTimeoutTimer.scheduleTimeoutCalled)
    }

    // onConnectionClosed schedules reconnectTimer timeout if connection cannot be made
    // after a previous clean disconnect
    func testSchedulesReconnectWhenNoConnectionOnCleanDisconnect() async {
        let mockTimeoutTimer = TimeoutTimerMock()
        let socket = createClosableSocket(timeoutTimer: mockTimeoutTimer)

        socket.disconnect()
        socket.connect()

        await socket.onConnectionClosed(code: 1001)
        XCTAssert(mockTimeoutTimer.scheduleTimeoutCalled)
    }

    // onConnectionClosed triggers channel error if joining
    func testOnConnectionClosedTriggerErrorWhileJoining() async {
        let socket = createClosableSocket()
        let channel = await socket.channel("topic")
        var errorCalled = false

        channel
            .on(ChannelEvent.error)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in errorCalled = true })
            .store(in: &cancellables)

        do {
            try await channel.join()
            let state = await channel.state
            XCTAssert(state == .joining)

            await socket.onConnectionClosed(code: 1001)
            XCTAssert(errorCalled)
        } catch {
            XCTFail("testOnConnectionClosedTriggerErrorWhileJoining Join threw an error")
        }
    }

    // onConnectionClosed triggers channel error if joined
    func testOnConnectionClosedTriggerErrorWhileJoined() async {
        let socket = createClosableSocket()
        let channel = await socket.channel("topic")
        var errorCalled = false

        channel
            .on(ChannelEvent.error)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in errorCalled = true })
            .store(in: &cancellables)

        do {
            let joinPush = try await channel.join()
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

            await socket.onConnectionClosed(code: 1001)
            XCTAssert(errorCalled)
        } catch {
            XCTFail("testOnConnectionClosedTriggerErrorWhileJoined Join threw an error")
        }
    }

    // onConnectionClosed does not trigger channel error after leave
    func testOnConnectionClosedDoesNotTriggerErrorAfterLeave() async {
        let socket = createClosableSocket()
        let channel = await socket.channel("topic")
        var errorCalled = false

        channel
            .on(ChannelEvent.error)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in errorCalled = true })
            .store(in: &cancellables)

        do {
            let joinPush = try await channel.join()
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
            await channel.leave(timeout: Defaults.timeoutInterval)

            await Task.yield()
            await waitForExpectations(timeout: 3)

            let state = await channel.state
            XCTAssert(state == .closed)

            await socket.onConnectionClosed(code: 1001)
            XCTAssertFalse(errorCalled)
        } catch {
            XCTFail("testOnConnectionClosedDoesNotTriggerErrorAfterLeave join threw an error")
        }
    }

    // onConnectionClosed triggers onClose callbacks
    func testOnConnectionClosedTriggersCallbacks() async {
        let socket = createClosableSocket()

        var oneCalled = 0
        socket.socketClosed
            .sink { oneCalled += 1 }
            .store(in: &cancellables)

        var twoCalled = 0
        socket.socketClosed
            .sink { twoCalled += 1 }
            .store(in: &cancellables)

        var threeCalled = 0
        socket.socketOpened
            .sink { threeCalled += 1 }
            .store(in: &cancellables)

        await socket.onConnectionClosed(code: 1000)
        XCTAssert(oneCalled == 1)
        XCTAssert(twoCalled == 1)
        XCTAssert(threeCalled == 0)
    }
}

extension SocketTests {
    // onConnectionError triggers onClose callbacks
    func testOnConnectionErrorTriggerCloseCallbacks() async {
        let socket = createTimeoutableSocket()
        var lastError: Error?
        socket.socketErrored
            .sink { (error) in lastError = error }
            .store(in: &cancellables)

        await socket.onError(error: TestError.stub)
        XCTAssertNotNil(lastError)
    }

    // onConnectionError triggers channel error if joining
    func testOnConnectionErrorTriggerChannelErrorIfJoining() async {
        let socket = createTimeoutableSocket()
        let channel = await socket.channel("topic")
        var errorCalled = false

        channel
            .on(ChannelEvent.error)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in  errorCalled = true })
            .store(in: &cancellables)

        do {
            try await channel.join()
            let state = await channel.state
            XCTAssert(state == .joining)

            await socket.onConnectionError(TestError.stub)
            XCTAssert(errorCalled)
        } catch {
            XCTFail("testOnConnectionErrorTriggerChannelErrorIfJoining join threw an error")
        }
    }

    // onConnectionError triggers channel error if joined
    func testOnConnectionErrorTriggerChannelErrorIfJoined() async {
        let socket = createTimeoutableSocket()
        let channel = await socket.channel("topic")
        var errorCalled = false

        channel
            .on(ChannelEvent.error)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in  errorCalled = true })
            .store(in: &cancellables)

        do {
            let joinPush = try await channel.join()
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

            await socket.onConnectionError(TestError.stub)
            XCTAssert(errorCalled)
        } catch {
            XCTFail("testOnConnectionErrorTriggerChannelErrorIfJoined join threw an error")
        }
    }

    // onConnectionError does not trigger channel error after leave
    func testOnConnectionErrorDoesNotTriggerChannelErrorAfterLeave() async {
        let socket = createTimeoutableSocket()
        let channel = await socket.channel("topic")
        var errorCalled = false

        channel
            .on(ChannelEvent.error)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in  errorCalled = true })
            .store(in: &cancellables)

        do {
            let joinPush = try await channel.join()
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
            await channel.leave(timeout: Defaults.timeoutInterval)

            await Task.yield()
            await waitForExpectations(timeout: 3)

            await socket.onConnectionError(TestError.stub)
            XCTAssertFalse(errorCalled)
        } catch {
            XCTFail("testOnConnectionErrorTriggerChannelErrorIfJoined join threw an error")
        }
    }
}

extension SocketTests {
    // onConnectionMessage parses raw message and triggers channel event
    func testOnConnectionMessageParsesCorrectly() async {
        let socket = createTimeoutableSocket()
        let targetChannel = await socket.channel("topic")
        let otherChannel = await  socket.channel("off-topic")

        var targetMessage: Message?
        targetChannel
            .on("event")
            .sink(receiveCompletion: { _ in },
                  receiveValue: { targetMessage = $0 })
            .store(in: &cancellables)

        var otherMessage: Message?
        otherChannel
            .on("event")
            .sink(receiveCompletion: { _ in },
                  receiveValue: { otherMessage = $0 })
            .store(in: &cancellables)

        let data: [Any?] = [nil, nil, "topic", "event", ["status": "ok", "response": ["one": "two"]]]
        let rawMessage = toWebSocketText(data: data)

        await socket.onConnectionMessage(rawMessage)
        XCTAssert(targetMessage?.topic == "topic")
        XCTAssert(targetMessage?.event == "event")
        XCTAssert(targetMessage?.payload["one"] as? String == "two")
        XCTAssertNil(otherMessage)
    }

    // onConnectionMessage triggers onMessage callbacks
    func testOnConnectionMessageTriggerCallbacks() async {
        let socket = createTimeoutableSocket()
        var message: Message?
        socket
            .socketRecievedMessage
            .sink { message = $0 }
            .store(in: &cancellables)

        let data: [Any?] = [nil, nil, "topic", "event", ["status": "ok", "response": ["one": "two"]]]
        let rawMessage = toWebSocketText(data: data)

        await socket.onConnectionMessage(rawMessage)
        XCTAssert(message?.topic == "topic")
        XCTAssert(message?.event == "event")
        XCTAssert(message?.payload["one"] as? String == "two")
    }

    // onConnectionMessage clears pending heartbeat
    func testOnConnectionMessageClearsPendingHeartbeat() async {
        let socket = createTimeoutableSocket()
        socket.pendingHeartbeatRef = "5"
        let rawMessage = "[null,\"5\",\"phoenix\",\"phx_reply\",{\"response\":{},\"status\":\"ok\"}]"
        await socket.onConnectionMessage(rawMessage)
        XCTAssertNil(socket.pendingHeartbeatRef)
    }
}
