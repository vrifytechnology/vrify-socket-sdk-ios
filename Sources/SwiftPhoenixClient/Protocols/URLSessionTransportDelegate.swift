//
//  URLSessionTransportDelegate.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-14.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------
// MARK: - Transport Protocol
// ----------------------------------------------------------------------
/**
 Delegate to receive notifications of events that occur in the `Transport` layer
 */
public protocol URLSessionTransportDelegate: AnyObject {

    /**
     Notified when the `Transport` opens.
     */
    func onOpen()

    /**
     Notified when the `Transport` receives an error.

     - Parameter error: Error from the underlying `Transport` implementation
     */
    func onError(error: Error) async

    /**
     Notified when the `Transport` receives a message from the server.

     - Parameter message: Message received from the server
     */
    func onMessage(message: String) async

    /**
     Notified when the `Transport` closes.

     - Parameter code: Code that was sent when the `Transport` closed
     */
    func onClose(code: Int) async
}
