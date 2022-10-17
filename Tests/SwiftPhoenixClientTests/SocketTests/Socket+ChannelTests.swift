//
//  Socket+ChannelTests.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-17.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import XCTest
import Combine
@testable import SwiftPhoenixClient

extension SocketTests {
    // returns channel with given topic and params
    func testCreateChannel() async {
        let socket = createTestSocket()
        let channel = await socket.channel("topic", params: ["one": "two"])
        socket.ref = 1006

        // No deep equal, so hack it
        let ref = await channel.socket?.ref
        XCTAssert(ref == socket.ref)

        XCTAssert(channel.topic == "topic")
        let params = await channel.params["one"]
        XCTAssert(params as? String == "two")
    }

    func testAddChannelToSocketsList() async {
        let socket = createTestSocket()
        XCTAssert(socket.channels.isEmpty)

        let channel = await socket.channel("topic", params: ["one": "two"])
        XCTAssert(socket.channels.count == 1)
        XCTAssert(socket.channels[0].topic == channel.topic)
    }

    // removes given channel from channels
    func testRemoveChannel() async {
        let socket = createTestSocket()
        let channel1 = await socket.channel("topic-1")
        let channel2 = await socket.channel("topic-2")

        await channel1.joinPush.ref = "1"
        await channel2.joinPush.ref = "2"

        await socket.remove(channel1)
        XCTAssert(socket.channels.count == 1)
        XCTAssert(socket.channels[0].topic == channel2.topic)
    }
}
