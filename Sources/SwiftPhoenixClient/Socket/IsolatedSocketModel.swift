//
//  IsolatedSocketModel.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2023-02-27.
//  Copyright © 2023 SwiftPhoenixClient. All rights reserved.
//

import Foundation

actor IsolatedSocketModel {
    internal var channels: [Channel] = []

    func add(channel: Channel) async {
        channels.append(channel)
    }

    func remove(channel: Channel) async {
        var channels: [Channel] = []

        for storedChannel in self.channels where await storedChannel.joinRef != channel.joinRef {
            channels.append(storedChannel)
        }

        self.channels = channels
    }
}
