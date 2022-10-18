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

import Foundation
import Combine

/// Represnts pushing data to a `Channel` through the `Socket`
public class Push {

    /// The channel sending the Push
    public weak var channel: Channel?

    /// The event, for example `phx_join`
    public let event: String

    /// The payload, for example ["user_id": "abc123"]
    public var payload: Payload

    /// The push timeout. Default is 10.0 seconds
    public var timeout: TimeInterval

    /// Publisher that emits the server's response to the Push
    public let pushResponse = CurrentValueSubject<Message?, PushError>(nil)

    /// The reference ID of the Push
    var ref: String?

    /// The event that is associated with the reference ID of the Push
    var refEvent: String?

    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Initializes a Push
    ///
    /// - parameter channel: The Channel
    /// - parameter event: The event, for example ChannelEvent.join
    /// - parameter payload: Optional. The Payload to send, e.g. ["user_id": "abc123"]
    /// - parameter timeout: The push timeout. A value of 0.0 will never generate a timeout Error.
    init(channel: Channel,
         event: String,
         payload: Payload = [:],
         timeout: TimeInterval) {
        self.channel = channel
        self.event = event
        self.payload = payload
        self.timeout = timeout
        self.ref = nil
    }

    /// Resets and sends the Push
    /// - parameter timeout: The push timeout. A value of 0.0 will never generate a timeout Error.
    public func resend(_ timeout: TimeInterval) async {
        self.timeout = timeout
        await self.reset()
        await self.send()
    }

    /// Sends the Push. If it has already timed out, then the call will
    /// be ignored and return early. Use `resend` in this case.
    public func send() async {
        guard !hasReceived(status: "timeout") else { return }

        await self.startTimeout()
        await self.channel?.socket?
            .push(topic: channel?.topic ?? "",
                  event: self.event,
                  payload: self.payload,
                  ref: self.ref,
                  joinRef: channel?.joinRef
            )
    }
}

extension Push {
    /// Resets the Push as it was after it was first initialized.
    func reset() async {
        self.ref = nil
        self.refEvent = nil
    }

    /// Starts the Timer which will trigger a timeout after a specific _timeout_
    /// time, in milliseconds, is reached.
    func startTimeout() async {
        guard
            let channel = channel,
            let socket = await channel.socket else { return }

        let ref = socket.makeRef()
        let refEvent = await channel.replyEventName(ref)

        self.ref = ref
        self.refEvent = refEvent

        if timeout == 0 {
            setupMessageCancellable(channel, refEvent, ref)
        } else {
            setupTimeoutableMessageCancellable(channel, refEvent, ref)
        }
    }

    func setupMessageCancellable(_ channel: Channel, _ refEvent: String, _ ref: String) {
        /// If a response is received  before the Timer triggers, cancel timer
        /// and match the recevied event to it's corresponding
        channel.messagePublisher
            .compactMap { $0 }
            .filter {
                $0.event == refEvent && $0.ref == ref
            }
            .sink(receiveCompletion: { [weak self] in
                if case .failure(let error) = $0,
                   self?.pushResponse.value == nil {
                    self?.handleMessagePublisher(error)
                }
            }, receiveValue: { [weak self] in
                self?.handleReceived(message: $0)
            })
            .store(in: &cancellables)
    }

    func setupTimeoutableMessageCancellable(_ channel: Channel, _ refEvent: String, _ ref: String) {
        /// If a response is received  before the Timer triggers, cancel timer
        /// and match the recevied event to it's corresponding
        channel.messagePublisher
            .compactMap { $0 }
            .filter { $0.event == refEvent && $0.ref == ref }
            .timeout(.seconds(timeout),
                     scheduler: DispatchQueue.global(),
                     customError: { [self] in .timeout(event: event, payload: payload) })
            .sink(receiveCompletion: { [weak self] in
                if case .failure(let error) = $0,
                   self?.pushResponse.value == nil {
                    self?.handleMessagePublisher(error)
                }
            }, receiveValue: { [weak self] in
                self?.handleReceived(message: $0)
            })
            .store(in: &cancellables)
    }

    func handleReceived(message: Message) {
        /// Check if there is event a status available
        guard message.status != nil else { return }
        pushResponse.send(message)
    }

    func handleMessagePublisher(_ error: PushError) {
        pushResponse.send(completion: .failure(error))
        Task { [weak self] in
            await self?.channel?.socket?.logItems("push",
"""
Push errored waiting for a response. Note that Phoenix does not require Channel responses.
Implementations of `handle_in` with {:noreply, socket} should not consider this an error in the case of a timeout.
""")
        }
    }

    /// Checks if a status has already been received by the Push.
    ///
    /// - parameter status: Status to check
    /// - return: True if given status has been received by the Push.
    func hasReceived(status: String) -> Bool {
        return self.pushResponse.value?.status == status
    }

    /// Triggers an event to be sent though the Channel
    func trigger(_ status: String, payload: Payload) async {
        /// If there is no ref event, then there is nothing to trigger on the channel
        guard let refEvent = self.refEvent else { return }

        var mutPayload = payload
        mutPayload["status"] = status

        await self.channel?.trigger(event: refEvent, payload: mutPayload, ref: ref ?? "")
    }
}
