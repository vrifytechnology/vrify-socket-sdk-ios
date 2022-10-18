//
//  Socket+PushTests.swift
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
    private func createPushTestsSocket(webSocket: URLSessionTransportMock = URLSessionTransportMock()) -> Socket {
        let socket = Socket(endPoint: "/socket", transport: { _ in webSocket })
        webSocket.readyState = .open
        socket.connect()
        return socket
    }

    // Push sends data to connection when connected
    func testPushSendData() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createPushTestsSocket(webSocket: mockWebSocket)
        socket.push(topic: "topic", event: "event", payload: ["one": "two"], ref: "6", joinRef: "2")

        XCTAssert(mockWebSocket.sendDataCalled)

        // swiftlint:disable:next force_cast
        let json = self.decode(mockWebSocket.sendDataReceivedData!) as! [Any]
        XCTAssert(json[0] as? String == "2")
        XCTAssert(json[1] as? String == "6")
        XCTAssert(json[2] as? String == "topic")
        XCTAssert(json[3] as? String == "event")
        XCTAssert(json[4] as? [String: String] == ["one": "two"])

        guard let stringData = String(data: mockWebSocket.sendDataReceivedData!, encoding: .utf8) else {
            XCTFail("Could not parse sendDataReceivedData")
            return
        }
        XCTAssert(stringData == "[\"2\",\"6\",\"topic\",\"event\",{\"one\":\"two\"}]")
    }

    // Push excludes ref information if not passed
    func testPushExcludesRefInfoIfNotPassed() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createPushTestsSocket(webSocket: mockWebSocket)
        socket.push(topic: "topic", event: "event", payload: ["one": "two"])

        // swiftlint:disable:next force_cast
        let json = self.decode(mockWebSocket.sendDataReceivedData!) as! [Any?]
        XCTAssertNil(json[0] as? String)
        XCTAssertNil(json[1] as? String)
        XCTAssert(json[2] as? String == "topic")
        XCTAssert(json[3] as? String == "event")
        XCTAssert(json[4] as? [String: String] == ["one": "two"])

        guard let stringData = String(data: mockWebSocket.sendDataReceivedData!, encoding: .utf8) else {
            XCTFail("Could not parse sendDataReceivedData")
            return
        }
        XCTAssert(stringData == "[null,null,\"topic\",\"event\",{\"one\":\"two\"}]")
    }

    // Push buffers data when not connected
    func testPushBuffersDataWhenNotConnected() {
        let mockWebSocket = URLSessionTransportMock()
        mockWebSocket.readyState = .closed
        let socket = Socket(endPoint: "/socket", transport: { _ in mockWebSocket })
        XCTAssert(socket.sendBuffer.isEmpty)

        socket.push(topic: "topic1", event: "event1", payload: ["one": "two"])
        XCTAssertFalse(mockWebSocket.sendDataCalled)
        XCTAssert(socket.sendBuffer.count == 1)

        socket.push(topic: "topic2", event: "event2", payload: ["one": "two"])
        XCTAssertFalse(mockWebSocket.sendDataCalled)
        XCTAssert(socket.sendBuffer.count == 2)

        socket.connect()

        socket.sendBuffer.forEach({ try? $0.callback() })
        XCTAssert(mockWebSocket.sendDataCalled)
        XCTAssert(mockWebSocket.sendDataCallsCount == 2)
    }
}
