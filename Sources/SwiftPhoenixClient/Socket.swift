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

public enum SocketError: Error {

    case abnormalClosureError

}

/// Alias for a JSON dictionary [String: Any]
public typealias Payload = [String: Any]

/// Alias for a function returning an optional JSON dictionary (`Payload?`)
public typealias PayloadClosure = () -> Payload?

/// ## Socket Connection
/// A single connection is established to the server and
/// channels are multiplexed over the connection.
/// Connect to the server using the `Socket` class:
///
/// ```swift
/// let socket = new Socket("/socket", paramsClosure: { ["userToken": "123" ] })
/// socket.connect()
/// ```
///
/// The `Socket` constructor takes the mount point of the socket,
/// the authentication params, as well as options that can be found in
/// the Socket docs, such as configuring the heartbeat.
public class Socket {

    // ----------------------------------------------------------------------
    // MARK: - Public Attributes
    // ----------------------------------------------------------------------
    /// The string WebSocket endpoint (ie `"ws://example.com/socket"`,
    /// `"wss://example.com"`, etc.) That was passed to the Socket during
    /// initialization. The URL endpoint will be modified by the Socket to
    /// include `"/websocket"` if missing.
    public let endPoint: String

    /// The fully qualified socket URL
    public private(set) var endPointUrl: URL

    /// Resolves to return the `paramsClosure` result at the time of calling.
    /// If the `Socket` was created with static params, then those will be
    /// returned every time.
    public var params: Payload? {
        return self.paramsClosure?()
    }

    /// The optional params closure used to get params whhen connecting. Must
    /// be set when initializaing the Socket.
    public let paramsClosure: PayloadClosure?

    /// The WebSocket transport. Default behavior is to provide a
    /// URLSessionWebsocketTask. See README for alternatives.
    private let transport: ((URL) -> URLSessionTransportProtocol)

    /// Phoenix serializer version, defaults to "2.0.0"
    public let vsn: String

    /// Override to provide custom encoding of data before writing to the socket
    public var encode: (Any) throws -> Data = Defaults.encode

    /// Override to provide customd decoding of data read from the socket
    public var decode: (Data) -> Any? = Defaults.decode

    /// Timeout to use when opening connections
    public var timeout: TimeInterval = Defaults.timeoutInterval

    /// Interval between sending a heartbeat
    public var heartbeatInterval: TimeInterval = Defaults.heartbeatInterval

    /// Interval between socket reconnect attempts, in seconds
    public var reconnectAfter: (Int) -> TimeInterval = Defaults.reconnectSteppedBackOff

    /// Interval between channel rejoin attempts, in seconds
    public var rejoinAfter: (Int) -> TimeInterval = Defaults.rejoinSteppedBackOff

    /// The optional function to receive logs
    public var logger: ((String) -> Void)?

    /// Disables heartbeats from being sent. Default is false.
    public var skipHeartbeat: Bool = false

    /// Enable/Disable SSL certificate validation. Default is false. This
    /// must be set before calling `socket.connect()` in order to be applied
    public var disableSSLCertValidation: Bool = false

    /// State change publishers
    public let socketOpened = PassthroughSubject<Void, Never>()
    public let socketClosed = PassthroughSubject<Void, Never>()
    public let socketErrored = PassthroughSubject<Error, Never>()
    public let socketRecievedMessage = PassthroughSubject<Message, Never>()

#if os(Linux)
#else
    /// Configure custom SSL validation logic, eg. SSL pinning. This
    /// must be set before calling `socket.connect()` in order to apply.
    //  public var security: SSLTrustValidator?

    /// Configure the encryption used by your client by setting the
    /// allowed cipher suites supported by your server. This must be
    /// set before calling `socket.connect()` in order to apply.
    public var enabledSSLCipherSuites: [SSLCipherSuite]?
#endif

    // ----------------------------------------------------------------------
    // MARK: - Private Attributes
    // ----------------------------------------------------------------------
    /// Collection on channels created for the Socket
    private var channels: [Channel] = []

    /// Buffers messages that need to be sent once the socket has connected. It is an array
    /// of tuples, with the ref of the message to send and the callback that will send the message.
    private var sendBuffer: [(ref: String?, callback: () throws -> Void)] = []

    /// Ref counter for messages
    private var ref: UInt64 = UInt64.min // 0 (max: 18,446,744,073,709,551,615)

    /// Timer that triggers sending new Heartbeat messages
    private var heartbeatTimer: HeartbeatTimer?

    /// Ref counter for the last heartbeat that was sent
    private var pendingHeartbeatRef: String?

    /// Timer to use when attempting to reconnect
    private var reconnectTimer: TimeoutTimer

    /// Close status
    private var closeStatus: CloseStatus = .unknown

    /// The connection to the server
    private var connection: URLSessionTransportProtocol?

    // ----------------------------------------------------------------------
    // MARK: - Initialization
    // ----------------------------------------------------------------------
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public convenience init(_ endPoint: String,
                            params: Payload? = nil,
                            vsn: String = Defaults.vsn) {
        self.init(endPoint: endPoint,
                  transport: { url in return URLSessionTransport(url: url) },
                  paramsClosure: { params },
                  vsn: vsn)
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    public convenience init(_ endPoint: String,
                            paramsClosure: PayloadClosure?,
                            vsn: String = Defaults.vsn) {
        self.init(endPoint: endPoint,
                  transport: { url in return URLSessionTransport(url: url) },
                  paramsClosure: paramsClosure,
                  vsn: vsn)
    }

    public init(endPoint: String,
                transport: @escaping ((URL) -> URLSessionTransportProtocol),
                paramsClosure: PayloadClosure? = nil,
                vsn: String = Defaults.vsn) {
        self.transport = transport
        self.paramsClosure = paramsClosure
        self.endPoint = endPoint
        self.vsn = vsn
        self.endPointUrl = Socket.buildEndpointUrl(endpoint: endPoint,
                                                   paramsClosure: paramsClosure,
                                                   vsn: vsn)

        self.reconnectTimer = TimeoutTimer()
        self.reconnectTimer.callback = { [weak self] in
            self?.logItems("Socket attempting to reconnect")
            self?.teardown { [weak self] in self?.connect() }
        }
        self.reconnectTimer.timerCalculation = { [weak self] tries -> TimeInterval in
            let interval = self?.reconnectAfter(tries) ?? Defaults.reconnectSteppedBackOff(tries)
            self?.logItems("Socket reconnecting in \(interval)s")
            return interval
        }
    }

    deinit {
        reconnectTimer.reset()
    }
}

extension Socket {
    // ----------------------------------------------------------------------
    // MARK: - Public
    // ----------------------------------------------------------------------
    /// - return: The socket protocol, wss or ws
    public var websocketProtocol: String {
        switch endPointUrl.scheme {
        case "https": return "wss"
        case "http": return "ws"
        default: return endPointUrl.scheme ?? ""
        }
    }

    /// - return: True if the socket is connected
    public var isConnected: Bool {
        return self.connection?.readyState == .open
    }

    /// Connects the Socket. The params passed to the Socket on initialization
    /// will be sent through the connection. If the Socket is already connected,
    /// then this call will be ignored.
    public func connect() {
        // Do not attempt to reconnect if the socket is currently connected
        guard !isConnected else { return }

        // Reset the close status when attempting to connect
        self.closeStatus = .unknown

        // We need to build this right before attempting to connect as the
        // parameters could be built upon demand and change over time
        self.endPointUrl = Socket.buildEndpointUrl(endpoint: self.endPoint,
                                                   paramsClosure: self.paramsClosure,
                                                   vsn: vsn)

        self.connection = self.transport(self.endPointUrl)
        self.connection?.delegate = self
        //    self.connection?.disableSSLCertValidation = disableSSLCertValidation
        //
        //    #if os(Linux)
        //    #else
        //    self.connection?.security = security
        //    self.connection?.enabledSSLCipherSuites = enabledSSLCipherSuites
        //    #endif

        self.connection?.connect()
    }

    /// Disconnects the socket
    ///
    /// - parameter code: Optional. Closing status code
    /// - paramter callback: Optional. Called when disconnected
    public func disconnect(code: CloseCode = CloseCode.normal,
                           callback: (() -> Void)? = nil) {
        // The socket was closed cleanly by the User
        self.closeStatus = CloseStatus(closeCode: code.rawValue)

        // Reset any reconnects and teardown the socket connection
        self.reconnectTimer.reset()
        self.teardown(code: code, callback: callback)
    }

    internal func teardown(code: CloseCode = CloseCode.normal, callback: (() -> Void)? = nil) {
        self.connection?.delegate = nil
        self.connection?.disconnect(code: code.rawValue, reason: nil)
        self.connection = nil

        // The socket connection has been torndown, heartbeats are not needed
        self.heartbeatTimer?.stop()

        // Since the connection's delegate was nil'd out, inform all state
        // callbacks that the connection has closed
        socketClosed.send()
        callback?()
    }

    // ----------------------------------------------------------------------
    // MARK: - Channel Initialization
    // ----------------------------------------------------------------------
    /// Initialize a new Channel
    ///
    /// Example:
    ///
    ///     let channel = socket.channel("rooms", params: ["user_id": "abc123"])
    ///
    /// - parameter topic: Topic of the channel
    /// - parameter params: Optional. Parameters for the channel
    /// - return: A new channel
    public func channel(_ topic: String,
                        params: [String: Any] = [:]) async -> Channel {
        let channel = await Channel(topic: topic, params: params, socket: self)
        self.channels.append(channel)

        return channel
    }

    /// Removes the Channel from the socket. This does not cause the channel to
    /// inform the server that it is leaving. You should call channel.leave()
    /// prior to removing the Channel.
    ///
    /// Example:
    ///
    ///     channel.leave()
    ///     socket.remove(channel)
    ///
    /// - parameter channel: Channel to remove
    public func remove(_ channel: Channel) async {
        var channels: [Channel] = []

        for storedChannel in self.channels where await storedChannel.joinRef != channel.joinRef {
            channels.append(storedChannel)
        }

        self.channels = channels
    }

    // ----------------------------------------------------------------------
    // MARK: - Sending Data
    // ----------------------------------------------------------------------
    /// Sends data through the Socket. This method is internal. Instead, you
    /// should call `push(_:, payload:, timeout:)` on the Channel you are
    /// sending an event to.
    ///
    /// - parameter topic:
    /// - parameter event:
    /// - parameter payload:
    /// - parameter ref: Optional. Defaults to nil
    /// - parameter joinRef: Optional. Defaults to nil
    internal func push(topic: String,
                       event: String,
                       payload: Payload,
                       ref: String? = nil,
                       joinRef: String? = nil) {

        let callback: (() throws -> Void) = {
            let body: [Any?] = [joinRef, ref, topic, event, payload]
            let data = try self.encode(body)

            self.logItems("push", "Sending \(String(data: data, encoding: String.Encoding.utf8) ?? "")" )

            self.connection?.send(data: data)
        }

        /// If the socket is connected, then execute the callback immediately.
        if isConnected {
            try? callback()
        } else {
            /// If the socket is not connected, add the push to a buffer which will
            /// be sent immediately upon connection.
            self.sendBuffer.append((ref: ref, callback: callback))
        }
    }

    /// - return: the next message ref, accounting for overflows
    public func makeRef() -> String {
        self.ref = (ref == UInt64.max) ? 0 : self.ref + 1
        return String(ref)
    }

    /// Logs the message. Override Socket.logger for specialized logging. noops by default
    ///
    /// - paramter items: List of items to be logged. Behaves just like debugPrint()
    func logItems(_ items: Any...) {
        let msg = items.map({ return String(describing: $0) }).joined(separator: ", ")
        self.logger?("SwiftPhoenixClient: \(msg)")
    }

    // ----------------------------------------------------------------------
    // MARK: - Connection Events
    // ----------------------------------------------------------------------
    /// Called when the underlying Websocket connects to it's host
    internal func onConnectionOpen() {
        self.logItems("transport", "Connected to \(endPoint)")

        // Reset the close status now that the socket has been connected
        self.closeStatus = .unknown

        // Send any messages that were waiting for a connection
        self.flushSendBuffer()

        // Reset how the socket tried to reconnect
        self.reconnectTimer.reset()

        // Restart the heartbeat timer
        self.resetHeartbeat()

        // Inform all onOpen callbacks that the Socket has opened
        self.socketOpened.send()
    }

    internal func onConnectionClosed(code: Int?) async {
        self.logItems("transport", "close")

        // Send an error to all channels
        await self.triggerChannelError()

        // Prevent the heartbeat from triggering if the
        self.heartbeatTimer?.stop()

        // Only attempt to reconnect if the socket did not close normally,
        // or if it was closed abnormally but on client side (e.g. due to heartbeat timeout)
        if self.closeStatus.shouldReconnect {
            await self.reconnectTimer.scheduleTimeout()
        }

        socketClosed.send()
    }

    internal func onConnectionError(_ error: Error) async {
        self.logItems("transport", error)

        // Send an error to all channels
        await self.triggerChannelError()

        // Inform any state callabcks of the error
        socketErrored.send(error)
    }

    internal func onConnectionMessage(_ rawMessage: String) async {
        self.logItems("receive ", rawMessage)

        guard
            let data = rawMessage.data(using: String.Encoding.utf8),
            let json = decode(data) as? [Any?],
            let message = Message(json: json)
        else {
            self.logItems("receive: Unable to parse JSON: \(rawMessage)")
            return }

        // Clear heartbeat ref, preventing a heartbeat timeout disconnect
        if message.ref == pendingHeartbeatRef { pendingHeartbeatRef = nil }

        if message.event == "phx_close" {
            print("Close Event Received")
        }

        // Dispatch the message to all channels that belong to the topic
        for channel in self.channels where await channel.isMember(message) {
            await channel.trigger(message)
        }

        // Inform all onMessage callbacks of the message
        socketRecievedMessage.send(message)
    }

    /// Triggers an error event to all of the connected Channels
    internal func triggerChannelError() async {
        for channel in self.channels {
            let isErrored = await channel.isErrored
            let isLeaving = await channel.isLeaving
            let isClosed = await channel.isClosed
            // Only trigger a channel error if it is in an "opened" state
            if !( isErrored || isLeaving || isClosed) {
                await channel.trigger(event: ChannelEvent.error)
            }
        }
    }

    /// Send all messages that were buffered before the socket opened
    internal func flushSendBuffer() {
        guard isConnected && sendBuffer.count > 0 else { return }
        self.sendBuffer.forEach({ try? $0.callback() })
        self.sendBuffer = []
    }

    /// Removes an item from the sendBuffer with the matching ref
    internal func removeFromSendBuffer(ref: String) {
        self.sendBuffer = self.sendBuffer.filter({ $0.ref != ref })
    }

    /// Builds a fully qualified socket `URL` from `endPoint` and `params`.
    internal static func buildEndpointUrl(endpoint: String, paramsClosure params: PayloadClosure?, vsn: String) -> URL {
        guard
            let url = URL(string: endpoint),
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { fatalError("Malformed URL: \(endpoint)") }

        // Ensure that the URL ends with "/websocket
        if !urlComponents.path.contains("/websocket") {
            // Do not duplicate '/' in the path
            if urlComponents.path.last != "/" {
                urlComponents.path.append("/")
            }

            // append 'websocket' to the path
            urlComponents.path.append("websocket")

        }

        urlComponents.queryItems = [URLQueryItem(name: "vsn", value: vsn)]

        // If there are parameters, append them to the URL
        if let params = params?() {
            urlComponents.queryItems?.append(contentsOf: params.map {
                URLQueryItem(name: $0.key, value: String(describing: $0.value))
            })
        }

        guard let qualifiedUrl = urlComponents.url
        else { fatalError("Malformed URL while adding parameters") }
        return qualifiedUrl
    }

    // Leaves any channel that is open that has a duplicate topic
    internal func leaveOpenTopic(topic: String) async {
        for channel in self.channels {
            let isInJoinedState = await channel.isJoined
            let isInJoiningState = await channel.isJoining
            if channel.topic == topic && (isInJoiningState || isInJoinedState) {
                self.logItems("transport", "leaving duplicate topic: [\(topic)]" )
                await channel.leave(timeout: Defaults.timeoutInterval)
            }
        }
    }

    // ----------------------------------------------------------------------
    // MARK: - Heartbeat
    // ----------------------------------------------------------------------
    internal func resetHeartbeat() {
        // Clear anything related to the heartbeat
        self.pendingHeartbeatRef = nil
        self.heartbeatTimer?.stop()

        // Do not start up the heartbeat timer if skipHeartbeat is true
        guard !skipHeartbeat else { return }

        self.heartbeatTimer = HeartbeatTimer(timeInterval: heartbeatInterval)
        self.heartbeatTimer?.start(eventHandler: { [weak self] in
            self?.sendHeartbeat()
        })
    }

    /// Sends a hearbeat payload to the phoenix serverss
    @objc func sendHeartbeat() {
        // Do not send if the connection is closed
        guard isConnected else { return }

        // If there is a pending heartbeat ref, then the last heartbeat was
        // never acknowledged by the server. Close the connection and attempt
        // to reconnect.
        if self.pendingHeartbeatRef != nil {
            self.pendingHeartbeatRef = nil
            self.logItems("transport",
                          "heartbeat timeout. Attempting to re-establish connection")

            // Close the socket manually, flagging the closure as abnormal. Do not use
            // `teardown` or `disconnect` as they will nil out the websocket delegate.
            self.abnormalClose("heartbeat timeout")

            return
        }

        // The last heartbeat was acknowledged by the server. Send another one
        self.pendingHeartbeatRef = self.makeRef()
        self.push(topic: "phoenix",
                  event: ChannelEvent.heartbeat,
                  payload: [:],
                  ref: self.pendingHeartbeatRef)
    }

    internal func abnormalClose(_ reason: String) {
        self.closeStatus = .abnormal

        /*
         We use NORMAL here since the client is the one determining to close the
         connection. However, we set to close status to abnormal so that
         the client knows that it should attempt to reconnect.

         If the server subsequently acknowledges with code 1000 (normal close),
         the socket will keep the `.abnormal` close status and trigger a reconnection.
         */
        self.connection?.disconnect(code: CloseCode.normal.rawValue, reason: reason)
    }
}

extension Socket: URLSessionTransportDelegate {
    // ----------------------------------------------------------------------
    // MARK: - TransportDelegate
    // ----------------------------------------------------------------------
    public func onOpen() {
        self.onConnectionOpen()
    }

    public func onError(error: Error) async {
        await self.onConnectionError(error)
    }

    public func onMessage(message: String) async {
        await self.onConnectionMessage(message)
    }

    public func onClose(code: Int) async {
        self.closeStatus.update(transportCloseCode: code)
        await self.onConnectionClosed(code: code)
    }
}

// ----------------------------------------------------------------------
// MARK: - Close Codes
// ----------------------------------------------------------------------
extension Socket {
    public enum CloseCode: Int {
        case abnormal = 999

        case normal = 1000

        case goingAway = 1001
    }
}

// ----------------------------------------------------------------------
// MARK: - Close Status
// ----------------------------------------------------------------------
extension Socket {
    /// Indicates the different closure states a socket can be in.
    enum CloseStatus {
        /// Undetermined closure state
        case unknown
        /// A clean closure requested either by the client or the server
        case clean
        /// An abnormal closure requested by the client
        case abnormal

        /// Temporarily close the socket, pausing reconnect attempts. Useful on mobile
        /// clients when disconnecting a because the app resigned active but should
        /// reconnect when app enters active state.
        case temporary

        init(closeCode: Int) {
            switch closeCode {
            case CloseCode.abnormal.rawValue:
                self = .abnormal
            case CloseCode.goingAway.rawValue:
                self = .temporary
            default:
                self = .clean
            }
        }

        mutating func update(transportCloseCode: Int) {
            switch self {
            case .unknown, .clean, .temporary:
                // Allow transport layer to override these statuses.
                self = .init(closeCode: transportCloseCode)
            case .abnormal:
                // Do not allow transport layer to override the abnormal close status.
                // The socket itself should reset it on the next connection attempt.
                // See `Socket.abnormalClose(_:)` for more information.
                break
            }
        }

        var shouldReconnect: Bool {
            switch self {
            case .unknown, .abnormal:
                return true
            case .clean, .temporary:
                return false
            }
        }
    }
}
