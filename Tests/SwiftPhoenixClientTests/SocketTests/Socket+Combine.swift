////
////  Socket+Combine.swift
////  SwiftPhoenixClient
////
////  Created by Jatinder Sidhu on 2022-10-17.
////  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
////
//
// import Foundation
//
//
//
// describe("onConnectionOpen") {
//    // Mocks
//    var mockWebSocket: URLSessionTransportMock!
//    var mockTimeoutTimer: TimeoutTimerMock!
//    let mockWebSocketTransport: ((URL) -> URLSessionTransportMock) = { _ in return mockWebSocket }
//
//    // UUT
//    var socket: Socket!
//
//    beforeEach {
//        mockWebSocket = URLSessionTransportMock()
//        mockTimeoutTimer = TimeoutTimerMock()
//        socket = Socket(endPoint: "/socket", transport: mockWebSocketTransport)
//        socket.reconnectAfter = { _ in return 10 }
//        socket.reconnectTimer = mockTimeoutTimer
//        socket.skipHeartbeat = true
//
//        mockWebSocket.readyState = .open
//        socket.connect()
//    }
//
//    it("flushes the send buffer", closure: {
//        var oneCalled = 0
//        socket.sendBuffer.append(("0", { oneCalled += 1 }))
//
//        socket.onConnectionOpen()
//        XCTAssert(oneCalled == 1))
//        XCTAssert(socket.sendBuffer == beEmpty())
//    })
//
//    it("resets reconnectTimer", closure: {
//        socket.onConnectionOpen()
//        XCTAssert(mockTimeoutTimer.resetCalled == beTrue())
//    })
//
//    it("triggers onOpen callbacks", closure: {
//        var oneCalled = 0
//        socket.onOpen { oneCalled += 1 }
//        var twoCalled = 0
//        socket.onOpen { twoCalled += 1 }
//        var threeCalled = 0
//        socket.onClose { threeCalled += 1 }
//
//        socket.onConnectionOpen()
//        XCTAssert(oneCalled == 1))
//        XCTAssert(twoCalled == 1))
//        XCTAssert(threeCalled == 0))
//    })
// }
//
// describe("onConnectionClosed") {
//    // Mocks
//    var mockWebSocket: URLSessionTransportMock!
//    var mockTimeoutTimer: TimeoutTimerMock!
//    let mockWebSocketTransport: ((URL) -> URLSessionTransportMock) = { _ in return mockWebSocket }
//
//    // UUT
//    var socket: Socket!
//
//    beforeEach {
//        mockWebSocket = URLSessionTransportMock()
//        mockTimeoutTimer = TimeoutTimerMock()
//        socket = Socket(endPoint: "/socket", transport: mockWebSocketTransport)
//        //        socket.reconnectAfter = { _ in return 10 }
//        socket.reconnectTimer = mockTimeoutTimer
//        //        socket.skipHeartbeat = true
//    }
//
//    it("schedules reconnectTimer timeout if normal close", closure: {
//        socket.onConnectionClosed(code: Socket.CloseCode.normal.rawValue)
//        XCTAssert(mockTimeoutTimer.scheduleTimeoutCalled == beTrue())
//    })
//
//    it("does not schedule reconnectTimer timeout if normal close after explicit disconnect", closure: {
//        socket.disconnect()
//        XCTAssert(mockTimeoutTimer.scheduleTimeoutCalled == beFalse())
//    })
//
//    it("schedules reconnectTimer timeout if not normal close", closure: {
//        socket.onConnectionClosed(code: 1001)
//        XCTAssert(mockTimeoutTimer.scheduleTimeoutCalled == beTrue())
//    })
//
//    it("schedules reconnectTimer timeout if connection cannot be made after a previous clean disconnect",
//       closure: {
//        socket.disconnect()
//        socket.connect()
//
//        socket.onConnectionClosed(code: 1001)
//        XCTAssert(mockTimeoutTimer.scheduleTimeoutCalled == beTrue())
//    })
//
//    it("triggers channel error if joining", closure: {
//        let channel = socket.channel("topic")
//        var errorCalled = false
//        channel.on(ChannelEvent.error, callback: { _ in
//            errorCalled = true
//        })
//
//        channel.join()
//        XCTAssert(channel.state == .joining))
//
//        socket.onConnectionClosed(code: 1001)
//        XCTAssert(errorCalled == beTrue())
//    })
//
//    it("triggers channel error if joined", closure: {
//        let channel = socket.channel("topic")
//        var errorCalled = false
//        channel.on(ChannelEvent.error, callback: { _ in
//            errorCalled = true
//        })
//
//        channel.join().trigger("ok", payload: [:])
//        XCTAssert(channel.state == .joined))
//
//        socket.onConnectionClosed(code: 1001)
//        XCTAssert(errorCalled == beTrue())
//    })
//
//    it("does not trigger channel error after leave", closure: {
//        let channel = socket.channel("topic")
//        var errorCalled = false
//        channel.on(ChannelEvent.error, callback: { _ in
//            errorCalled = true
//        })
//
//        channel.join().trigger("ok", payload: [:])
//        channel.leave()
//        XCTAssert(channel.state == .closed))
//
//        socket.onConnectionClosed(code: 1001)
//        XCTAssert(errorCalled == beFalse())
//    })
//
//    it("triggers onClose callbacks", closure: {
//        var oneCalled = 0
//        socket.onClose { oneCalled += 1 }
//        var twoCalled = 0
//        socket.onClose { twoCalled += 1 }
//        var threeCalled = 0
//        socket.onOpen { threeCalled += 1 }
//
//        socket.onConnectionClosed(code: 1000)
//        XCTAssert(oneCalled == 1))
//        XCTAssert(twoCalled == 1))
//        XCTAssert(threeCalled == 0))
//    })
// }
//
// describe("onConnectionError") {
//    // Mocks
//    var mockWebSocket: URLSessionTransportMock!
//    var mockTimeoutTimer: TimeoutTimerMock!
//    let mockWebSocketTransport: ((URL) -> URLSessionTransportMock) = { _ in return mockWebSocket }
//
//    // UUT
//    var socket: Socket!
//
//    beforeEach {
//        mockWebSocket = URLSessionTransportMock()
//        mockTimeoutTimer = TimeoutTimerMock()
//        socket = Socket(endPoint: "/socket", transport: mockWebSocketTransport)
//        socket.reconnectAfter = { _ in return 10 }
//        socket.reconnectTimer = mockTimeoutTimer
//        socket.skipHeartbeat = true
//
//        mockWebSocket.readyState = .open
//        socket.connect()
//    }
//
//    it("triggers onClose callbacks", closure: {
//        var lastError: Error?
//        socket.onError(callback: { (error) in lastError = error })
//
//        socket.onConnectionError(TestError.stub)
//        XCTAssert(lastError).toNot(beNil())
//    })
//
//    it("triggers channel error if joining", closure: {
//        let channel = socket.channel("topic")
//        var errorCalled = false
//        channel.on(ChannelEvent.error, callback: { _ in
//            errorCalled = true
//        })
//
//        channel.join()
//        XCTAssert(channel.state == .joining))
//
//        socket.onConnectionError(TestError.stub)
//        XCTAssert(errorCalled == beTrue())
//    })
//
//    it("triggers channel error if joined", closure: {
//        let channel = socket.channel("topic")
//        var errorCalled = false
//        channel.on(ChannelEvent.error, callback: { _ in
//            errorCalled = true
//        })
//
//        channel.join().trigger("ok", payload: [:])
//        XCTAssert(channel.state == .joined))
//
//        socket.onConnectionError(TestError.stub)
//        XCTAssert(errorCalled == beTrue())
//    })
//
//    it("does not trigger channel error after leave", closure: {
//        let channel = socket.channel("topic")
//        var errorCalled = false
//        channel.on(ChannelEvent.error, callback: { _ in
//            errorCalled = true
//        })
//
//        channel.join().trigger("ok", payload: [:])
//        channel.leave()
//        XCTAssert(channel.state == .closed))
//
//        socket.onConnectionError(TestError.stub)
//        XCTAssert(errorCalled == beFalse())
//    })
// }
//
// describe("onConnectionMessage") {
//    // Mocks
//    var mockWebSocket: URLSessionTransportMock!
//    var mockTimeoutTimer: TimeoutTimerMock!
//    let mockWebSocketTransport: ((URL) -> URLSessionTransportMock) = { _ in return mockWebSocket }
//
//    // UUT
//    var socket: Socket!
//
//    beforeEach {
//        mockWebSocket = URLSessionTransportMock()
//        mockTimeoutTimer = TimeoutTimerMock()
//        socket = Socket(endPoint: "/socket", transport: mockWebSocketTransport)
//        socket.reconnectAfter = { _ in return 10 }
//        socket.reconnectTimer = mockTimeoutTimer
//        socket.skipHeartbeat = true
//
//        mockWebSocket.readyState = .open
//        socket.connect()
//    }
//
//    it("parses raw message and triggers channel event", closure: {
//        let targetChannel = socket.channel("topic")
//        let otherChannel = socket.channel("off-topic")
//
//        var targetMessage: Message?
//        targetChannel.on("event", callback: { (msg) in targetMessage = msg })
//
//        var otherMessage: Message?
//        otherChannel.on("event", callback: { (msg) in otherMessage = msg })
//
//        let data: [Any?] = [nil, nil, "topic", "event", ["status": "ok", "response": ["one": "two"]]]
//        let rawMessage = toWebSocketText(data: data)
//
//        socket.onConnectionMessage(rawMessage)
//        XCTAssert(targetMessage?.topic == "topic"))
//        XCTAssert(targetMessage?.event == "event"))
//        XCTAssert(targetMessage?.payload["one"] as? String == "two"))
//        XCTAssert(otherMessage == beNil())
//    })
//
//    it("triggers onMessage callbacks", closure: {
//        var message: Message?
//        socket.onMessage(callback: { (msg) in message = msg })
//
//        let data: [Any?] = [nil, nil, "topic", "event", ["status": "ok", "response": ["one": "two"]]]
//        let rawMessage = toWebSocketText(data: data)
//
//        socket.onConnectionMessage(rawMessage)
//        XCTAssert(message?.topic == "topic"))
//        XCTAssert(message?.event == "event"))
//        XCTAssert(message?.payload["one"] as? String == "two"))
//    })
//
//    it("clears pending heartbeat", closure: {
//        socket.pendingHeartbeatRef = "5"
//        let rawMessage = "[null,\"5\",\"phoenix\",\"phx_reply\",{\"response\":{},\"status\":\"ok\"}]"
//        socket.onConnectionMessage(rawMessage)
//        XCTAssert(socket.pendingHeartbeatRef == beNil())
//    })
// }
// }
