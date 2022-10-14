//
//  URLSessionTransportProtocol.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-14.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

// ----------------------------------------------------------------------
// MARK: - Transport Protocol
// ----------------------------------------------------------------------
/**
 Defines a `Socket`'s Transport layer.
 */
// sourcery: AutoMockable
public protocol URLSessionTransportProtocol {

    /// The current `ReadyState` of the `Transport` layer
    var readyState: TransportReadyState { get }

    /// Delegate for the `Transport` layer
    var delegate: URLSessionTransportDelegate? { get set }

    /**
     Connect to the server
     */
    func connect()

    /**
     Disconnect from the server.

     - Parameters:
     - code: Status code defined by <ahref="http://tools.ietf.org/html/rfc6455#section-7.4">Section 7.4 of RFC 6455</a>.
     - reason: Reason why the connection is closing. Optional.
     */
    func disconnect(code: Int, reason: String?)

    /**
     Sends a message to the server.

     - Parameter data: Data to send.
     */
    func send(data: Data)
}
