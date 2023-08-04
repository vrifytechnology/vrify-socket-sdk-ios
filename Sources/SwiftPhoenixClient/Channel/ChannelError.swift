//
//  ChannelError.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-18.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import Foundation

public enum ChannelError: Error {
    case alreadyJoined
    case pushedBeforeJoined
}

extension ChannelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadyJoined:
            return NSLocalizedString("'join' can only be called a single time per channel instance",
                                     comment: "ChannelError")
        case .pushedBeforeJoined:
            return NSLocalizedString("Pushed before joining. See: channel.join()", comment: "ChannelError")
        }
    }
}
