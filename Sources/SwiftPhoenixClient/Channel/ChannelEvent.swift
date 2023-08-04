//
//  ChannelEvent.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-14.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

/// Represents the different events that can be sent through
/// a channel regarding a Channel's lifecycle.
public struct ChannelEvent {
    public static let heartbeat = "heartbeat"
    public static let join      = "phx_join"
    public static let leave     = "phx_leave"
    public static let reply     = "phx_reply"
    public static let error     = "phx_error"
    public static let close     = "phx_close"

    static func isLifecyleEvent(_ event: String) -> Bool {
        switch event {
        case join, leave, reply, error, close: return true
        default: return false
        }
    }
}
