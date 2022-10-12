// Copyright (c) 2021 David Stump <david@davidstump.net>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Swift
import Combine
import Foundation

///
/// Represents a Channel which is bound to a topic
///
/// A Channel can bind to multiple events on a given topic and
/// be informed when those events occur within a topic.
///
/// ### Example:
///
///     let channel = socket.channel("room:123", params: ["token": "Room Token"])
///     channel.on("new_msg") { payload in print("Got message", payload") }
///     channel.push("new_msg, payload: ["body": "This is a message"])
///         .receive("ok") { payload in print("Sent message", payload) }
///         .receive("error") { payload in print("Send failed", payload) }
///         .receive("timeout") { payload in print("Networking issue...", payload) }
///
///     channel.join()
///         .receive("ok") { payload in print("Channel Joined", payload) }
///         .receive("error") { payload in print("Failed ot join", payload) }
///         .receive("timeout") { payload in print("Networking issue...", payload) }
///

import Foundation

public actor Channel {

    /// The topic of the Channel. e.g. "rooms:friends"
    public nonisolated let topic: String

    /// The params sent when joining the channel
    public var params: Payload {
        didSet { self.joinPush.payload = params }
    }

    /// The Socket that the channel belongs to
    weak var socket: Socket?

    /// Current state of the Channel
    var state: ChannelState

    /// Publishes messages recieved by the channel
    public nonisolated let messagePublisher = PassthroughSubject<Message, PushError>()

    /// Timout when attempting to join a Channel
    var timeout: TimeInterval

    /// Set to true once the channel calls .join()
    var joinedOnce: Bool

    /// Push to send when the channel calls .join()
    var joinPush: Push!

    /// Buffer of Pushes that will be sent once the Channel's socket connects
    var pushBuffer: [Push]

    /// Timer to attempt to rejoin
    var rejoinTimer: TimeoutTimer

    /// Refs of stateChange hooks
    var stateChangeRefs: [String]

    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Initialize a Channel
    ///
    /// - parameter topic: Topic of the Channel
    /// - parameter params: Optional. Parameters to send when joining.
    /// - parameter socket: Socket that the channel is a part of
    init(topic: String, params: [String: Any] = [:], socket: Socket) async {
        self.state = ChannelState.closed
        self.topic = topic
        self.params = params
        self.socket = socket
        self.timeout = socket.timeout
        self.joinedOnce = false
        self.pushBuffer = []
        self.stateChangeRefs = []
        self.rejoinTimer = TimeoutTimer()

        // Setup Push Event to be sent when joining
        self.joinPush = Push(channel: self,
                             event: ChannelEvent.join,
                             payload: params,
                             timeout: socket.timeout)
        self.setupDelegates()
        self.setupJoinPushSinks()
    }

    func setupDelegates() {
        // Setup Timer delgation
        self.rejoinTimer.callback
            .delegate(to: self) { (self) in
                Task {
                    if await self.socket?.isConnected == true { await self.rejoin() }
                }
            }

        self.rejoinTimer.timerCalculation = { [weak self] tries -> TimeInterval in
            return await self?.socket?.rejoinAfter(tries) ?? 5.0
        }

        // Respond to socket events
        let onErrorRef = self.socket?.delegateOnError(to: self, callback: { (self, _) in
            Task { await self.rejoinTimer.reset() }
        })
        if let ref = onErrorRef { self.stateChangeRefs.append(ref) }

        let onOpenRef = self.socket?.delegateOnOpen(to: self, callback: { (self) in
            Task {
                await self.rejoinTimer.reset()
                if await (self.isErrored) { await self.rejoin() }
            }
        })
        if let ref = onOpenRef { self.stateChangeRefs.append(ref) }
    }

    func setupJoinPushSinks() {
        /// Handle when a response is received after join()
        joinPush
            .pushResponse
            .compactMap { $0 }
            .filter { $0.status == "ok"}
            .sink(receiveCompletion: { [weak self] in
                switch $0 {
                case .failure(let error):
                    Task { [weak self] in await self?.handleJoinPush(error: error) }
                default:
                    break
                }
            }, receiveValue: { [weak self] _ in
                Task { [weak self] in
                    // Mark the Channel as joined
                    await self?.update(state: ChannelState.joined)

                    // Reset the timer, preventing it from attempting to join again
                    await self?.rejoinTimer.reset()

                    // Send any buffered messages and clear the buffer
                    guard let pushBuffer = await self?.pushBuffer else { return }

                    for element in pushBuffer {
                        await element.send()
                    }
                    await self?.clearPushBuffer()
                }
            })
            .store(in: &cancellables)

        /// Perfom when the Channel has been closed
        messagePublisher
            .filter { $0.event == ChannelEvent.close }
            .sink(receiveCompletion: { [weak self] in
                if case let .failure(error) = $0 {
                    Task { [weak self] in
                        await self?.socket?.logItems("presence", "Push failed due to error: \(error)")
                    }
                }
            }, receiveValue: { [weak self] message in
                Task { [weak self] in
                    // Reset any timer that may be on-going
                    await self?.rejoinTimer.reset()

                    // Log that the channel was left
                    await self?.socket?.logItems("channel",
                                                 "close topic: \(self?.topic) joinRef: \(await self?.joinRef ?? "nil")")

                    // Mark the channel as closed and remove it from the socket
                    await self?.update(state: .closed)
                    guard let channel = self else { return }
                    await self?.socket?.remove(channel)
                }
            })
            .store(in: &cancellables)

        /// Perfom when the Channel errors
        messagePublisher
            .filter { $0.event == ChannelEvent.error }
            .sink(receiveCompletion: { [weak self] in
                if case let .failure(error) = $0 {
                    Task { [weak self] in
                        await self?.socket?.logItems("presence", "Push failed due to error: \(error)")
                    }
                }
            }, receiveValue: { [weak self] message in
                Task { [weak self] in
                    // Log that the channel received an error
                    await self?.socket?.logItems("channel",
                                                 "error topic: \(self?.topic) joinRef: \(await self?.joinRef ?? "nil") message: \(message)")

                    // If error was received while joining, then reset the Push
                    if await (self?.isJoining ?? false) {
                        // Make sure that the "phx_join" isn't buffered to send once the socket
                        // reconnects. The channel will send a new join event when the socket connects.
                        if let safeJoinRef = await self?.joinRef {
                            await self?.socket?.removeFromSendBuffer(ref: safeJoinRef)
                        }

                        // Reset the push to be used again later
                        await self?.joinPush.reset()
                    }

                    // Mark the channel as errored and attempt to rejoin if socket is currently connected
                    await self?.update(state: .errored)
                    if await (self?.socket?.isConnected == true) {
                        await self?.rejoinTimer.scheduleTimeout()
                    }
                }
            })
            .store(in: &cancellables)

        // Perform when the join reply is received
        messagePublisher
            .filter { $0.event == ChannelEvent.reply }
            .sink(receiveCompletion: { [weak self] in
                if case let .failure(error) = $0 {
                    Task { [weak self] in
                        await self?.socket?.logItems("presence", "Push failed due to error: \(error)")
                    }
                }
            }, receiveValue: { [weak self] message in
                Task { [weak self] in
                    guard let event = await self?.replyEventName(message.ref) else { return }
                    await self?.trigger(event: event,
                                        payload: message.rawPayload,
                                        ref: message.ref,
                                        joinRef: message.joinRef)
                }
            })
            .store(in: &cancellables)

    }

    func handleJoinPush(error: PushError) {
        switch error {
        case .pushFailed:
            Task { [weak self] in
                await self?.update(state: .errored)
                if await (self?.socket?.isConnected == true) {
                    await self?.rejoinTimer.scheduleTimeout()
                }
            }
        case .timeout:
            Task { [weak self] in
                guard let channel = self else { return }

                // log that the channel timed out
                await self?.socket?
                    .logItems("channel",
                              "timeout \(channel.topic) \(channel.joinRef ?? "") after \(await channel.timeout)s")

                // Send a Push to the server to leave the channel
                let leavePush = await Push(channel: channel,
                                           event: ChannelEvent.leave,
                                           timeout: channel.timeout)
                await leavePush.send()

                // Mark the Channel as in an error and attempt to rejoin if socket is connected
                await self?.update(state: .errored)
                await self?.joinPush.reset()

                if await (self?.socket?.isConnected == true) {
                    await self?.rejoinTimer.scheduleTimeout()
                }
            }
        }
    }

    deinit {
        rejoinTimer.reset()
    }

    /// Joins the channel
    ///
    /// - parameter timeout: Optional. Defaults to Channel's timeout
    /// - return: Push event
    @discardableResult
    public func join(timeout: TimeInterval? = nil) async -> Push {
        guard !joinedOnce else {
            fatalError("tried to join multiple times. 'join' "
                       + "can only be called a single time per channel instance")
        }

        // Join the Channel
        if let safeTimeout = timeout { self.timeout = safeTimeout }

        self.joinedOnce = true
        await self.rejoin()
        return joinPush
    }

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
    public func createPush(_ event: String,
                           payload: Payload,
                           timeout: TimeInterval) -> Push {
        guard joinedOnce else { fatalError("Tried to push \(event) to \(self.topic) before joining. Use channel.join() before pushing events") }

        return Push(channel: self,
                    event: event,
                    payload: payload,
                    timeout: timeout)
    }

    /// Sends a Push over the Socket for the Channel
    ///
    /// Example:
    ///
    ///     channel.send(push)
    ///
    /// - parameter push: Push object to send over the Socket
    public func send(_ push: Push) async {
        guard joinedOnce else { fatalError("Tried to push \(push.event) to \(self.topic) before joining. Use channel.join() before pushing events") }

        if canPush {
            await push.send()
        } else {
            await push.startTimeout()
            pushBuffer.append(push)
        }
    }

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
    public func leave(timeout: TimeInterval) async -> Push {
        // If attempting a rejoin during a leave, then reset, cancelling the rejoin
        self.rejoinTimer.reset()

        // Now set the state to leaving
        self.state = .leaving

        /// Delegated callback for a successful or a failed channel leave
        var onCloseDelegate = Delegated<Message, Void>()
        onCloseDelegate.delegate(to: self) { (self, message) in

        }

        // Push event to send to the server
        let leavePush = Push(channel: self,
                             event: ChannelEvent.leave,
                             timeout: timeout)

        // Perform the same behavior if successfully left the channel
        // or if sending the event timed out
        leavePush
            .pushResponse
            .compactMap { $0 }
            .sink(receiveCompletion: { [weak self] in
                switch $0 {
                case .failure(let error):
                    switch error {
                    case .timeout:
                        Task { [weak self] in await self?.handleLeavePush() }
                    case .pushFailed:
                        Task { [weak self] in await self?.socket?.logItems("channel", "leave Push failed") }
                    }
                default:
                    break
                }
            }, receiveValue: { [weak self] _ in
                Task { [weak self] in await self?.handleLeavePush() }
            })
            .store(in: &cancellables)

        await leavePush.send()

        // If the Channel cannot send push events, trigger a success locally
        if !canPush { await leavePush.trigger("ok", payload: [:]) }

        // Return the push so it can be bound to
        return leavePush
    }

    private func handleLeavePush() {
        Task { [weak self] in
            guard let channel = self else { return }
            await channel.socket?.logItems("channel", "leave \(channel.topic)")

            // Triggers onClose() hooks
            await channel.trigger(event: ChannelEvent.close, payload: ["reason": "leave"])
        }
    }


    //----------------------------------------------------------------------
    // MARK: - Internal
    //----------------------------------------------------------------------
    /// Checks if an event received by the Socket belongs to this Channel
    func isMember(_ message: Message) -> Bool {
        // Return false if the message's topic does not match the Channel's topic
        guard message.topic == self.topic else { return false }

        guard
            let safeJoinRef = message.joinRef,
            safeJoinRef != self.joinRef,
            ChannelEvent.isLifecyleEvent(message.event)
        else { return true }

        self.socket?.logItems("channel", "dropping outdated message", message.topic, message.event, message.rawPayload, safeJoinRef)
        return false
    }

    /// Sends the payload to join the Channel
    func sendJoin(_ timeout: TimeInterval) async {
        self.state = ChannelState.joining
        await self.joinPush.resend(timeout)
    }

    /// Rejoins the channel
    func rejoin(_ timeout: TimeInterval? = nil) async {
        // Do not attempt to rejoin if the channel is in the process of leaving
        guard !self.isLeaving else { return }

        // Leave potentially duplicate channels
        await self.socket?.leaveOpenTopic(topic: self.topic)

        // Send the joinPush
        await self.sendJoin(timeout ?? self.timeout)
    }

    /// Triggers an event to the correct event bindings created by
    /// `channel.on("event")`.
    ///
    /// - parameter message: Message to pass to the event bindings
    func trigger(_ message: Message) {
        self.messagePublisher.send(message)
    }

    /// Triggers an event to the correct event bindings created by
    //// `channel.on("event")`.
    ///
    /// - parameter event: Event to trigger
    /// - parameter payload: Payload of the event
    /// - parameter ref: Ref of the event. Defaults to empty
    /// - parameter joinRef: Ref of the join event. Defaults to nil
    func trigger(event: String,
                 payload: Payload = [:],
                 ref: String = "",
                 joinRef: String? = nil) {
        let message = Message(ref: ref,
                              topic: self.topic,
                              event: event,
                              payload: payload,
                              joinRef: joinRef ?? self.joinRef)
        self.trigger(message)
    }

    /// - parameter ref: The ref of the event push
    /// - return: The event name of the reply
    func replyEventName(_ ref: String) -> String {
        return "chan_reply_\(ref)"
    }

    /// The Ref send during the join message.
    var joinRef: String? {
        return self.joinPush.ref
    }

    /// - return: True if the Channel can push messages, meaning the socket
    ///           is connected and the channel is joined
    var canPush: Bool {
        return self.socket?.isConnected == true && self.isJoined
    }
}


//----------------------------------------------------------------------
// MARK: - Public API
//----------------------------------------------------------------------
extension Channel {

    /// - return: True if the Channel has been closed
    public var isClosed: Bool {
        return state == .closed
    }

    /// - return: True if the Channel experienced an error
    public var isErrored: Bool {
        return state == .errored
    }

    /// - return: True if the channel has joined
    public var isJoined: Bool {
        return state == .joined
    }

    /// - return: True if the channel has requested to join
    public var isJoining: Bool {
        return state == .joining
    }

    /// - return: True if the channel has requested to leave
    public var isLeaving: Bool {
        return state == .leaving
    }

}

private extension Channel {
    private func update(state:  ChannelState) async {
        self.state = state
    }

    private func clearPushBuffer() async {
        self.pushBuffer = []
    }
}

