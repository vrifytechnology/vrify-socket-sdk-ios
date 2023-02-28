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
        let socket = createSocketTestsSocket()
        let channel = await socket.channel("topic", params: ["one": "two"])
        socket.ref = 1006

        // No deep equal, so hack it
        let ref = await channel.socket?.ref
        XCTAssert(ref == socket.ref)

        XCTAssert(channel.topic == "topic")
        let params = await channel.params["one"]
        XCTAssert(params as? String == "two")
    }

    // adds channel to sockets channel list
    func testAddChannelToSocketsList() async {
        let socket = createSocketTestsSocket()
        let channels = await socket.isolatedModel.channels
        XCTAssert(channels.isEmpty)

        let channel = await socket.channel("topic", params: ["one": "two"])
        let updatedChannel = await socket.isolatedModel.channels
        XCTAssert(updatedChannel.count == 1)
        XCTAssert(updatedChannel[0].topic == channel.topic)
    }

    // removes given channel from channels
    func testRemoveChannel() async {
        let socket = createSocketTestsSocket()
        let channel1 = await socket.channel("topic-1")
        let channel2 = await socket.channel("topic-2")

        await channel1.joinPush.ref = "1"
        await channel2.joinPush.ref = "2"

        await socket.remove(channel1)
        let channels = await socket.isolatedModel.channels
        XCTAssert(channels.count == 1)
        XCTAssert(channels[0].topic == channel2.topic)
    }
}
