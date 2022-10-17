//
//  MessageTests.swift
//  SwiftPhoenixClientTests
//
//  Created by Daniel Rees on 10/27/21.
//  Copyright © 2021 SwiftPhoenixClient. All rights reserved.
//

import XCTest
@testable import SwiftPhoenixClient

class MessageTests: XCTestCase {
    func testJsonParsingOfValidMessage() {
        let json: [Any] = ["2", "6", "my-topic", "update", ["user": "James S.", "message": "This is a test"]]

        let message = Message(json: json)
        XCTAssert(message?.ref == "6")
        XCTAssert(message?.joinRef == "2")
        XCTAssert(message?.topic == "my-topic")
        XCTAssert(message?.event == "update")
        XCTAssert(message?.payload["user"] as? String == "James S.")
        XCTAssert(message?.payload["message"] as? String == "This is a test")
        XCTAssertNil(message?.status)
    }

    func testJsonParsingOfValidReply() {
        let json: [Any] = ["2",
                           "6",
                           "my-topic",
                           "phx_reply",
                           ["response": ["user": "James S.", "message": "This is a test"], "status": "ok"]]

        let message = Message(json: json)
        XCTAssert(message?.ref == "6")
        XCTAssert(message?.joinRef == "2")
        XCTAssert(message?.topic == "my-topic")
        XCTAssert(message?.event == "phx_reply")
        XCTAssert(message?.payload["user"] as? String == "James S.")
        XCTAssert(message?.payload["message"] as? String == "This is a test")
        XCTAssert(message?.status == "ok")
    }
}
