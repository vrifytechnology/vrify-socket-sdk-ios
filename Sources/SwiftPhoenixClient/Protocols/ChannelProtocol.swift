//
//  ChannelProtocol.swift
//  SwiftPhoenixClient
//
//  Created by Jatinder Sidhu on 2022-10-17.
//  Copyright © 2022 SwiftPhoenixClient. All rights reserved.
//

import Foundation
import Combine

internal protocol ChannelProtocol: Actor {
    /// The topic of the Channel. e.g. "rooms:friends"
    var topic: String { get }

    /// The params sent when joining the channel
    var params: Payload { get }

    /// The Socket that the channel belongs to
    var socket: Socket? { get }

    /// Current state of the Channel
    var state: ChannelState { get set}

    /// Publishes messages recieved by the channel
    var messagePublisher: PassthroughSubject<Message, PushError> { get }

    /// Timout when attempting to join a Channel
    var timeout: TimeInterval { get }

    /// Set to true once the channel calls .join()
    var joinedOnce: Bool { get }

    /// Push to send when the channel calls .join()
    var joinPush: Push! { get }

    /// Buffer of Pushes that will be sent once the Channel's socket connects
    var pushBuffer: [Push] { get set }

    /// Timer to attempt to rejoin
    var rejoinTimer: TimeoutTimer { get }

    /// Refs of stateChange hooks
    var stateChangeRefs: [String] { get }

    /// The Ref send during the join message.
    var joinRef: String? { get }

    /// - return: True if the Channel can push messages, meaning the socket
    ///           is connected and the channel is joined
    var canPush: Bool { get }

    /// - return: True if the Channel has been closed
    var isClosed: Bool { get }

    /// - return: True if the Channel experienced an error
    var isErrored: Bool { get }

    /// - return: True if the channel has joined
    var isJoined: Bool { get }

    /// - return: True if the channel has requested to join
    var isJoining: Bool { get }

    /// - return: True if the channel has requested to leave
    var isLeaving: Bool { get }

    /// Joins the channel
    ///
    /// - parameter timeout: Optional. Defaults to Channel's timeout
    /// - return: Push event
    @discardableResult
    func join(timeout: TimeInterval?) async -> Push

    /// Creates a Push with a payload for the Channel
    ///
    /// Example:
    ///
    ///     channel.createPush("event", payload: ["message": "hello"), timeout: Default.timeoutInterval)
    ///
    /// - parameter event: Event to push
    /// - parameter payload: Payload to push
    /// - parameter timeout: Timeout. A timeout of 0.0 will never result in a timeout Error.
    @discardableResult
    func createPush(_ event: String, payload: Payload, timeout: TimeInterval) -> Push

    /// Sends a Push over the Socket for the Channel
    ///
    /// Example:
    ///
    ///     channel.send(push)
    ///
    /// - parameter push: Push object to send over the Socket
    func send(_ push: Push) async

    /// Leaves the channel
    ///
    /// Unsubscribes from server events, and instructs channel to terminate on
    /// server
    ///
    /// Triggers onClose() hooks
    ///
    /// To receive leave acknowledgements, use the a `receive`
    /// hook to bind to the server ack, ie:
    ///
    /// Example:
    ////
    ///     channel.leave().receive("ok") { _ in { print("left") }
    ///
    /// - parameter timeout: Optional timeout
    /// - return: Push that can add receive hooks
    @discardableResult
    func leave(timeout: TimeInterval) async -> Push

    /// Checks if an event received by the Socket belongs to this Channel
    func isMember(_ message: Message) -> Bool

    /// Sends the payload to join the Channel
    func sendJoin(_ timeout: TimeInterval) async

    /// Rejoins the channel
    func rejoin(_ timeout: TimeInterval?) async

    /// Triggers an event to the correct event bindings created by
    /// `channel.on("event")`.
    ///
    /// - parameter message: Message to pass to the event bindings
    func trigger(_ message: Message)

    /// Triggers an event to the correct event bindings created by
    //// `channel.on("event")`.
    ///
    /// - parameter event: Event to trigger
    /// - parameter payload: Payload of the event
    /// - parameter ref: Ref of the event. Defaults to empty
    /// - parameter joinRef: Ref of the join event. Defaults to nil
    func trigger(event: String, payload: Payload, ref: String, joinRef: String?)

    /// - parameter ref: The ref of the event push
    /// - return: The event name of the reply
    func replyEventName(_ ref: String) -> String
}
