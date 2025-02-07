//
//  Socket+HeartbeatTests.swift
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
    private func createHeartbeatTestSocket(webSocket: URLSessionTransportMock = URLSessionTransportMock()) -> Socket {
        let socket = Socket(endPoint: "/socket", transport: { _ in webSocket })
        webSocket.readyState = .open
        socket.connect()
        return socket
    }

    // disconnect invalidates the heartbeat timer
    func testOnDisconnectInvalidateHeartbeatTimer() async {
        let socket = createHeartbeatTestSocket()
        await socket.resetHeartbeat()

        guard let heartbeatTimer = socket.heartbeatTimer else {
            XCTFail("heartbeattimer was Nil")
            return
        }

        XCTAssert(heartbeatTimer.isValid)
        socket.disconnect()
        XCTAssertFalse(heartbeatTimer.isValid)
    }

    // disconnect does nothing if not connected
    func testOnDisconnectNoSideEffects() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createHeartbeatTestSocket(webSocket: mockWebSocket)
        socket.disconnect()
        XCTAssert(mockWebSocket.disconnectCodeReasonCalled)
    }
}

extension SocketTests {
    // resetHeartbeat clears any pending heartbeat
    func testResetHeartbeatClearsPendingHearbeat() async {
        let socket = createHeartbeatTestSocket()
        socket.pendingHeartbeatRef = "1"
        await socket.resetHeartbeat()

        XCTAssertNil(socket.pendingHeartbeatRef)
    }

    // resetHeartbeat does not schedule heartbeat if skipHeartbeat == true
    func testResetHeartbeatSkipHeartbeat() async {
        let socket = createHeartbeatTestSocket()
        socket.skipHeartbeat = true
        await socket.resetHeartbeat()

        XCTAssertNil(socket.heartbeatTimer)
    }

    // resetHeartbeat creates a timer and sends a heartbeat
    func testResetHeartbeatSendsHeartbeat() async {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createHeartbeatTestSocket(webSocket: mockWebSocket)
        socket.heartbeatInterval = 1
        await socket.resetHeartbeat()

        guard let heartbeatTimer = socket.heartbeatTimer else {
            XCTFail("heartbeattimer was Nil")
            return
        }
        XCTAssert(heartbeatTimer.timeInterval == 1)

        // Fire the timer
        heartbeatTimer.fire()
        await Task.yield()
        XCTAssert(mockWebSocket.sendDataCalled)
        let json = self.decode(mockWebSocket.sendDataReceivedData!) as? [Any?]
        XCTAssertNil(json?[0] as? String)
        XCTAssert(json?[1] as? String == String(socket.ref))
        XCTAssert(json?[2] as? String == "phoenix")
        XCTAssert(json?[3] as? String == ChannelEvent.heartbeat)
        XCTAssert((json?[4] as? [String: Any] ?? ["not empty": ""]).isEmpty)
    }

    // resetHeartbeat should invalidate an old timer and create a new one
    func testResetHeartbeatInvalidatesOldTimer() async {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createHeartbeatTestSocket(webSocket: mockWebSocket)

        XCTAssertNil(socket.heartbeatTimer)
        await socket.resetHeartbeat()

        guard let oldTimer = socket.heartbeatTimer,
              let heartbeatTimer = socket.heartbeatTimer else {
            XCTFail("heartbeattimer was Nil")
            return
        }

        XCTAssert(heartbeatTimer.isValid)
        await socket.resetHeartbeat()

        XCTAssertFalse(oldTimer.isValid)
        XCTAssert(oldTimer != socket.heartbeatTimer)
    }
}

extension SocketTests {
    // sendHeartbeat closes socket when heartbeat is not ack'd within heartbeat window
    func testSendHearbeatNotAckdClosesSocket() async {
        let mockWebSocket = URLSessionTransportMock()
        let socket = Socket(endPoint: "/socket", transport: { _ in mockWebSocket })
        mockWebSocket.readyState = .open

        socket.connect()
        await socket.sendHeartbeat()
        XCTAssertFalse(mockWebSocket.disconnectCodeReasonCalled)
        XCTAssertNotNil(socket.pendingHeartbeatRef)

        await socket.sendHeartbeat()
        XCTAssert(mockWebSocket.disconnectCodeReasonCalled)
        XCTAssertNil(socket.pendingHeartbeatRef)
    }

    // sendHeartbeat pushes heartbeat data when connected
    func testSendHearbeatPushesHeartbeatWhenConnected() async {
        let mockWebSocket = URLSessionTransportMock()
        let socket = Socket(endPoint: "/socket", transport: { _ in mockWebSocket })
        mockWebSocket.readyState = .open

        socket.connect()
        await socket.sendHeartbeat()

        XCTAssert(socket.pendingHeartbeatRef == String(socket.ref))
        XCTAssert(mockWebSocket.sendDataCalled)

        let json = self.decode(mockWebSocket.sendDataReceivedData!) as? [Any?]
        XCTAssertNil(json?[0] as? String)
        XCTAssert(json?[1] as? String == socket.pendingHeartbeatRef)
        XCTAssert(json?[2] as? String == "phoenix")
        XCTAssert(json?[3] as? String == "heartbeat")
        XCTAssert((json?[4] as? [String: String] ?? ["": ""]).isEmpty)

        guard let stringData = String(data: mockWebSocket.sendDataReceivedData!, encoding: .utf8) else {
            XCTFail("Could not parse sendDataReceivedData")
            return
        }
        XCTAssert(stringData == "[null,\"1\",\"phoenix\",\"heartbeat\",{}]")
    }

    // sendHeartbeat does nothing when not connected
    func testSendHearbeatDoesNothingWhenNotConnected() async {
        let mockWebSocket = URLSessionTransportMock()
        let socket = Socket(endPoint: "/socket", transport: { _ in mockWebSocket })
        mockWebSocket.readyState = .closed

        await socket.sendHeartbeat()

        XCTAssertFalse(mockWebSocket.disconnectCodeReasonCalled)
        XCTAssertFalse(mockWebSocket.sendDataCalled)
    }
}
