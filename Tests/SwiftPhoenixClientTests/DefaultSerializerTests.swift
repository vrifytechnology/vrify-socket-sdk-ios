//
//  DefaultSerializerTests.swift
//  SwiftPhoenixClient
//
//  Created by Daniel Rees on 1/17/19.
//

import XCTest
@testable import SwiftPhoenixClient

class DefaultSerializerTests: XCTestCase {
    func testEncodeDecode() {
        let body: [Any] = ["join_ref", "ref", "topic", "event", ["user_id": "abc123"]]
        let data = Defaults.encode(body)
        expect(String(data: data,
                      encoding: .utf8)).to(equal("[\"join_ref\",\"ref\",\"topic\",\"event\",{\"user_id\":\"abc123\"}]"))

        let json = Defaults.decode(data) as? [Any]

        let message = Message(json: json!)
        XCTAssert(message?.ref == "ref")
        XCTAssert(message?.joinRef == "join_ref")
        XCTAssert(message?.topic == "topic")
        XCTAssert(message?.event == "event")
        XCTAssert(message?.payload["user_id"] as? String == "abc123")
    }
}
