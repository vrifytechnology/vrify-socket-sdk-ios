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
    private func createTimeoutableSocket(timeoutTimer: TimeoutTimer = TimeoutTimerMock(),
                                         webSocket: URLSessionTransportMock = URLSessionTransportMock()) -> Socket {
        let socket = Socket(endPoint: "/socket", transport: { _ in webSocket })
        socket.reconnectAfter = { _ in return 10 }
        socket.reconnectTimer = timeoutTimer

        webSocket.readyState = .open
        socket.connect()
        return socket
    }

    // disconnect invalidates the heartbeat timer
    func testOnDisconnectInvalidateHeartbeatTimer() {
        let socket = createTimeoutableSocket()

        var timerCalled = 0
        let queue = DispatchQueue(label: "test.heartbeat")
        let timer = HeartbeatTimer(timeInterval: 10, queue: queue)

        timer.start { timerCalled += 1 }

        socket.heartbeatTimer = timer

        socket.disconnect()
        XCTAssertFalse(socket.heartbeatTimer?.isValid ?? true)
        timer.fire()
        XCTAssert(timerCalled == 0)
    }

    // disconnect does nothing if not connected
    func testOnDisconnectNoSideEffects() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createTimeoutableSocket(webSocket: mockWebSocket)
        socket.disconnect()
        XCTAssert(mockWebSocket.disconnectCodeReasonCalled)
    }
}

extension SocketTests {
    // resetHeartbeat clears any pending heartbeat
    func testResetHeartbeatClearsPendingHearbeat() {
        let socket = createTimeoutableSocket()
        socket.pendingHeartbeatRef = "1"
        socket.resetHeartbeat()

        XCTAssertNil(socket.pendingHeartbeatRef)
    }

    // resetHeartbeat does not schedule heartbeat if skipHeartbeat == true
    func testResetHeartbeatSkipHeartbeat() {
        let socket = createTimeoutableSocket()
        socket.skipHeartbeat = true
        socket.resetHeartbeat()

        XCTAssertNil(socket.heartbeatTimer)
    }

    // resetHeartbeat creates a timer and sends a heartbeat
    func testResetHeartbeatSendsHeartbeat() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createTimeoutableSocket(webSocket: mockWebSocket)
        socket.heartbeatInterval = 1

        XCTAssertNil(socket.heartbeatTimer)
        socket.resetHeartbeat()

        XCTAssertNotNil(socket.heartbeatTimer)
        XCTAssert(socket.heartbeatTimer?.timeInterval == 1)

        // Fire the timer
        socket.heartbeatTimer?.fire()
        XCTAssert(mockWebSocket.sendDataCalled)
        let json = self.decode(mockWebSocket.sendDataReceivedData!) as? [Any?]
        XCTAssertNil(json?[0] as? String)
        XCTAssert(json?[1] as? String == String(socket.ref))
        XCTAssert(json?[2] as? String == "phoenix")
        XCTAssert(json?[3] as? String == ChannelEvent.heartbeat)
        XCTAssert((json?[4] as? [String: Any] ?? ["not empty": ""]).isEmpty)
    }

    // resetHeartbeat should invalidate an old timer and create a new one
    func testResetHeartbeatInvalidatesOldTimer() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createTimeoutableSocket(webSocket: mockWebSocket)
        let queue = DispatchQueue(label: "test.heartbeat")
        let timer = HeartbeatTimer(timeInterval: 1000, queue: queue)

        var timerCalled = 0
        timer.start { timerCalled += 1 }
        socket.heartbeatTimer = timer

        XCTAssert(timer.isValid)
        socket.resetHeartbeat()

        XCTAssertFalse(timer.isValid)
        XCTAssert(socket.heartbeatTimer != timer)
    }
}


// describe("sendHeartbeat v1") {
//    // Mocks
//    var mockWebSocket: URLSessionTransportMock!
//
//    // UUT
//    var socket: Socket!
//
//    beforeEach {
//        mockWebSocket = URLSessionTransportMock()
//        socket = Socket("/socket")
//        socket.connection = mockWebSocket
//    }
//
//    it("closes socket when heartbeat is not ack'd within heartbeat window", closure: {
//        mockWebSocket.readyState = .open
//        socket.sendHeartbeat()
//        XCTAssert(mockWebSocket.disconnectCodeReasonCalled == beFalse())
//        XCTAssert(socket.pendingHeartbeatRef).toNot(beNil())
//
//        socket.sendHeartbeat()
//        XCTAssert(mockWebSocket.disconnectCodeReasonCalled == beTrue())
//        XCTAssert(socket.pendingHeartbeatRef == beNil())
//    })
//
//    it("pushes heartbeat data when connected", closure: {
//        mockWebSocket.readyState = .open
//
//        socket.sendHeartbeat()
//
//        XCTAssert(socket.pendingHeartbeatRef == String(socket.ref)))
//        XCTAssert(mockWebSocket.sendDataCalled == beTrue())
//
//        let json = self.decode(mockWebSocket.sendDataReceivedData!) as? [Any?]
//        XCTAssert(json?[0] as? String == beNil())
//        XCTAssert(json?[1] as? String == socket.pendingHeartbeatRef))
//        XCTAssert(json?[2] as? String == "phoenix"))
//        XCTAssert(json?[3] as? String == "heartbeat"))
//        XCTAssert(json?[4] as? [String: String] == beEmpty())
//
//        XCTAssert(String(data: mockWebSocket.sendDataReceivedData!, encoding: .utf8))
//            .to("[null,\"1\",\"phoenix\",\"heartbeat\",{}]"))
//    })
//
//    it("does nothing when not connected", closure: {
//        mockWebSocket.readyState = .closed
//        socket.sendHeartbeat()
//
//        XCTAssert(mockWebSocket.disconnectCodeReasonCalled == beFalse())
//        XCTAssert(mockWebSocket.sendDataCalled == beFalse())
//    })
// }
