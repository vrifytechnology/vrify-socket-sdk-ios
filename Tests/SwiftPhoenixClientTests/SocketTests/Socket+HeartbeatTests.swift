////
////  Socket+HeartbeatTests.swift
////  SwiftPhoenixClient
////
////  Created by Jatinder Sidhu on 2022-10-17.
////  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
////
//
// import Foundation
//
//
// describe("disconnect") {
//    it("invalidates and invalidates the heartbeat timer", closure: {
//        var timerCalled = 0
//        let queue = DispatchQueue(label: "test.heartbeat")
//        let timer = HeartbeatTimer(timeInterval: 10, queue: queue)
//
//        timer.start { timerCalled += 1 }
//
//        socket.heartbeatTimer = timer
//
//        socket.disconnect()
//        XCTAssert(socket.heartbeatTimer?.isValid == beFalse())
//        timer.fire()
//        XCTAssert(timerCalled == 0))
//    })
//
//    it("does nothing if not connected", closure: {
//        socket.disconnect()
//        XCTAssert(mockWebSocket.disconnectCodeReasonCalled == beFalse())
//    })
// }
//
//
// describe("resetHeartbeat") {
//    // Mocks
//    var mockWebSocket: URLSessionTransportMock!
//    let mockWebSocketTransport: ((URL) -> URLSessionTransportMock) = { _ in return mockWebSocket }
//
//    // UUT
//    var socket: Socket!
//
//    beforeEach {
//        mockWebSocket = URLSessionTransportMock()
//        socket = Socket(endPoint: "/socket", transport: mockWebSocketTransport)
//
//    }
//
//    it("clears any pending heartbeat", closure: {
//        socket.pendingHeartbeatRef = "1"
//        socket.resetHeartbeat()
//
//        XCTAssert(socket.pendingHeartbeatRef == beNil())
//    })
//
//    it("does not schedule heartbeat if skipHeartbeat == true", closure: {
//        socket.skipHeartbeat = true
//        socket.resetHeartbeat()
//
//        XCTAssert(socket.heartbeatTimer == beNil())
//    })
//
//    it("creates a timer and sends a heartbeat", closure: {
//        mockWebSocket.readyState = .open
//        socket.connect()
//        socket.heartbeatInterval = 1
//
//        XCTAssert(socket.heartbeatTimer == beNil())
//        socket.resetHeartbeat()
//
//        XCTAssert(socket.heartbeatTimer).toNot(beNil())
//        XCTAssert(socket.heartbeatTimer?.timeInterval == 1))
//
//        // Fire the timer
//        socket.heartbeatTimer?.fire()
//        XCTAssert(mockWebSocket.sendDataCalled == beTrue())
//        let json = self.decode(mockWebSocket.sendDataReceivedData!) as? [Any?]
//        XCTAssert(json?[0] as? String == beNil())
//        XCTAssert(json?[1] as? String == String(socket.ref)))
//        XCTAssert(json?[2] as? String == "phoenix"))
//        XCTAssert(json?[3] as? String == ChannelEvent.heartbeat))
//        XCTAssert(json?[4] as? [String: Any] == beEmpty())
//    })
//
//    it("should invalidate an old timer and create a new one", closure: {
//        mockWebSocket.readyState = .open
//        let queue = DispatchQueue(label: "test.heartbeat")
//        let timer = HeartbeatTimer(timeInterval: 1000, queue: queue)
//
//        var timerCalled = 0
//        timer.start { timerCalled += 1 }
//        socket.heartbeatTimer = timer
//
//        XCTAssert(timer.isValid == beTrue())
//        socket.resetHeartbeat()
//
//        XCTAssert(timer.isValid == beFalse())
//        XCTAssert(socket.heartbeatTimer).toNot(timer))
//    })
// }
//
//
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
