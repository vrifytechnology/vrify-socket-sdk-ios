//
//  ChannelState.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-14.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

/// Represents the multiple states that a Channel can be in
/// throughout it's lifecycle.
public enum ChannelState: String {
    case closed
    case errored
    case joined
    case joining
    case leaving
}
