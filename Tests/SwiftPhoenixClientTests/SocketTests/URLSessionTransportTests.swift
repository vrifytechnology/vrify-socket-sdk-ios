//
//  URLSessionTransportTests.swift
//  SwiftPhoenixClientTests
//
//  Created by Daniel Rees on 4/1/21.
//  Copyright © 2021 SwiftPhoenixClient. All rights reserved.
//

import XCTest
@testable import SwiftPhoenixClient

class URLSessionTransportTests: XCTestCase {
    // constructor should construct a valid URL
    func testHttptoWSSchemeReplacement() {
        let transportHttp = URLSessionTransport(url: URL(string: "http://localhost:4000/socket/websocket")!)
        XCTAssert(transportHttp.url.absoluteString == "ws://localhost:4000/socket/websocket")

        let transportHttps = URLSessionTransport(url: URL(string: "https://localhost:4000/socket/websocket")!)
        XCTAssert(transportHttps.url.absoluteString == "wss://localhost:4000/socket/websocket")

        let transportWs = URLSessionTransport(url: URL(string: "ws://localhost:4000/socket/websocket")!)
        XCTAssert(transportWs.url.absoluteString == "ws://localhost:4000/socket/websocket")

        let transportWss = URLSessionTransport(url: URL(string: "wss://localhost:4000/socket/websocket")!)
        XCTAssert(transportWss.url.absoluteString == "wss://localhost:4000/socket/websocket")
    }

    // constructor overrides some defaults
    func testOverRideConfiguration() {
        let configuration = URLSessionConfiguration.default
        let overrideTransport = URLSessionTransport(url: URL(string: "wss://localhost:4000")!,
                                                    configuration: configuration)

        XCTAssert(overrideTransport.configuration == configuration)
    }
}
