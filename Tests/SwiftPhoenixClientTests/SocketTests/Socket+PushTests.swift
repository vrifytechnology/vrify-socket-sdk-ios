////
////  Socket+PushTests.swift
////  SwiftPhoenixClient
////
////  Created by Jatinder Sidhu on 2022-10-17.
////  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
////
//
// import Foundation
//
// describe("push") {
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
//    }
//
//    it("sends data to connection when connected", closure: {
//        mockWebSocket.readyState = .open
//        socket.connect()
//        socket.push(topic: "topic", event: "event", payload: ["one": "two"], ref: "6", joinRef: "2")
//
//        XCTAssert(mockWebSocket.sendDataCalled == beTrue())
//        // swiftlint:disable:next force_cast
//        let json = self.decode(mockWebSocket.sendDataReceivedData!) as! [Any]
//        XCTAssert(json[0] as? String == "2"))
//        XCTAssert(json[1] as? String == "6"))
//        XCTAssert(json[2] as? String == "topic"))
//        XCTAssert(json[3] as? String == "event"))
//        XCTAssert(json[4] as? [String: String] == ["one": "two"]))
//
//        XCTAssert(String(data: mockWebSocket.sendDataReceivedData!, encoding: .utf8))
//            .to("[\"2\",\"6\",\"topic\",\"event\",{\"one\":\"two\"}]"))
//    })
//
//    it("excludes ref information if not passed", closure: {
//        mockWebSocket.readyState = .open
//        socket.connect()
//        socket.push(topic: "topic", event: "event", payload: ["one": "two"])
//        // swiftlint:disable:next force_cast
//        let json = self.decode(mockWebSocket.sendDataReceivedData!) as! [Any?]
//        XCTAssert(json[0] as? String == beNil())
//        XCTAssert(json[1] as? String == beNil())
//        XCTAssert(json[2] as? String == "topic"))
//        XCTAssert(json[3] as? String == "event"))
//        XCTAssert(json[4] as? [String: String] == ["one": "two"]))
//
//        XCTAssert(String(data: mockWebSocket.sendDataReceivedData!, encoding: .utf8))
//            .to("[null,null,\"topic\",\"event\",{\"one\":\"two\"}]"))
//    })
//
//    it("buffers data when not connected", closure: {
//        mockWebSocket.readyState = .closed
//        socket.connect()
//
//        XCTAssert(socket.sendBuffer == beEmpty())
//
//        socket.push(topic: "topic1", event: "event1", payload: ["one": "two"])
//        XCTAssert(mockWebSocket.sendDataCalled == beFalse())
//        XCTAssert(socket.sendBuffer == haveCount(1))
//
//        socket.push(topic: "topic2", event: "event2", payload: ["one": "two"])
//        XCTAssert(mockWebSocket.sendDataCalled == beFalse())
//        XCTAssert(socket.sendBuffer == haveCount(2))
//
//        socket.sendBuffer.forEach({ try? $0.callback() })
//        XCTAssert(mockWebSocket.sendDataCalled == beTrue())
//        XCTAssert(mockWebSocket.sendDataCallsCount == 2))
//    })
// }
