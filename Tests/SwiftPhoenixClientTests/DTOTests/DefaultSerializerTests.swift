//
//  DefaultSerializerTests.swift
//  SwiftPhoenixClient
//
//  Created by Daniel Rees on 1/17/19.
//

import XCTest
@testable import SwiftPhoenixClient

class DefaultSerializerTests: XCTestCase {
    // encode and decode message converts dictionary to Data and back to Message
    func testEncodeDecode() {
        let body: [Any] = ["join_ref", "ref", "topic", "event", ["user_id": "abc123"]]
        guard let data = try? Defaults.encode(body) else {
            XCTFail("Failed to decode JSON")
            return
        }
        let expectedDecode = "[\"join_ref\",\"ref\",\"topic\",\"event\",{\"user_id\":\"abc123\"}]"
        XCTAssert(String(data: data, encoding: .utf8) == expectedDecode)

        let json = Defaults.decode(data) as? [Any]

        let message = Message(json: json!)
        XCTAssert(message?.ref == "ref")
        XCTAssert(message?.joinRef == "join_ref")
        XCTAssert(message?.topic == "topic")
        XCTAssert(message?.event == "event")
        XCTAssert(message?.payload["user_id"] as? String == "abc123")
    }
}
