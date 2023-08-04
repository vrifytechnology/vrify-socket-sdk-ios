//
//  IsolatedSocketModel.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2023-02-27.
//  Copyright © 2023 SwiftPhoenixClient. All rights reserved.
//

import Foundation

actor IsolatedSocketModel {
    typealias SuspendedMessage = (ref: String?, callback: () throws -> Void)

    /// Collection of channels created for the Socket
    var channels: [Channel] = []

    /// Buffers messages that need to be sent once the socket has connected. It is an array
    /// of tuples, with the ref of the message to send and the callback that will send the message.
    var sendBuffer: [SuspendedMessage] = []
}

extension IsolatedSocketModel {
    func append(channel: Channel) async {
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

extension IsolatedSocketModel {
    func append(message: SuspendedMessage) {
        sendBuffer.append(message)
    }

    func clearSendBuffer() {
        sendBuffer = []
    }

    func removeFromSendBuffer(ref: String) {
        sendBuffer = sendBuffer.filter({ $0.ref != ref })
    }
}
