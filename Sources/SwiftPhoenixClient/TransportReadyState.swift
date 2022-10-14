//
//  TransportReadyState.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-14.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------
// MARK: - Transport Ready State Enum
// ----------------------------------------------------------------------
/**
 Available `ReadyState`s of a `Transport` layer.
 */
public enum TransportReadyState {

    /// The `Transport` is opening a connection to the server.
    case connecting

    /// The `Transport` is connected to the server.
    case open

    /// The `Transport` is closing the connection to the server.
    case closing

    /// The `Transport` has disconnected from the server.
    case closed

}
