//
//  SocketTests.swift
//  SwiftPhoenixClient
//
//  Created by Daniel Rees on 2/10/18.
//

import XCTest
import Combine
@testable import SwiftPhoenixClient

class SocketTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    private let encode = Defaults.encode
    let decode = Defaults.decode

    func createSocketTestsSocket(webSocket: URLSessionTransportProtocol = URLSessionTransportMock()) -> Socket {
        let socket = Socket(endPoint: "/socket", transport: { _ in
            webSocket
        })
        socket.skipHeartbeat = true
        return socket
    }

    // constructor sets defaults
    func testConstructorDefaults() async {
        let socket = Socket("wss://localhost:4000/socket")
        let channels = await socket.isolatedModel.channels
        XCTAssert(channels.count == 0)
        XCTAssert(socket.sendBuffer.count == 0)
        XCTAssert(socket.ref == 0)
        XCTAssert(socket.endPoint == "wss://localhost:4000/socket")
        XCTAssert(socket.timeout == Defaults.timeoutInterval)
        XCTAssert(socket.heartbeatInterval == Defaults.heartbeatInterval)
        XCTAssertNil(socket.logger)
        XCTAssert(socket.reconnectAfter(1) == 0.010) // 10ms
        XCTAssert(socket.reconnectAfter(2) == 0.050) // 50ms
        XCTAssert(socket.reconnectAfter(3) == 0.100) // 100ms
        XCTAssert(socket.reconnectAfter(4) == 0.150) // 150ms
        XCTAssert(socket.reconnectAfter(5) == 0.200) // 200ms
        XCTAssert(socket.reconnectAfter(6) == 0.250) // 250ms
        XCTAssert(socket.reconnectAfter(7) == 0.500) // 500ms
        XCTAssert(socket.reconnectAfter(8) == 1.000) // 1_000ms (1s)
        XCTAssert(socket.reconnectAfter(9) == 2.000) // 2_000ms (2s)
        XCTAssert(socket.reconnectAfter(10) == 5.00) // 5_000ms (5s)
        XCTAssert(socket.reconnectAfter(11) == 5.00) // 5_000ms (5s)
    }

    // constructor overrides some defaults
    func testDefaultOverrides() {
        let socket = Socket("wss://localhost:4000/socket", paramsClosure: { ["one": 2] })
        socket.timeout = 40000
        socket.heartbeatInterval = 60000
        socket.logger = { _ in }
        socket.reconnectAfter = { _ in return 10 }

        XCTAssert(socket.timeout == 40000)
        XCTAssert(socket.heartbeatInterval == 60000)
        XCTAssertNotNil(socket.logger)
        XCTAssert(socket.reconnectAfter(1) == 10)
        XCTAssert(socket.reconnectAfter(2) == 10)
    }

    // constructor should construct a valid URL
    func testValidSocketURLs() {
        // test vsn
        let socket = Socket("http://localhost:4000/socket/websocket",
                            paramsClosure: { ["token": "abc123"] },
                            vsn: "1.0.0")
        XCTAssert(socket.endPointUrl.absoluteString == "http://localhost:4000/socket/websocket?vsn=1.0.0&token=abc123")

        // test params
        let socketParams = Socket("http://localhost:4000/socket/websocket", paramsClosure: { ["token": "abc123"] })
        let expectedEndpoint = "http://localhost:4000/socket/websocket?vsn=2.0.0&token=abc123"
        XCTAssert(socketParams.endPointUrl.absoluteString == expectedEndpoint)

        let socketParams2 = Socket("ws://localhost:4000/socket/websocket",
                                   paramsClosure: { ["token": "abc123", "user_id": 1] })
        // absoluteString does not seem to return a string with the params in a deterministic order
        let expectedEndpoints = [
            "ws://localhost:4000/socket/websocket?vsn=2.0.0&token=abc123&user_id=1",
            "ws://localhost:4000/socket/websocket?vsn=2.0.0&user_id=1&token=abc123"
        ]
        XCTAssert(expectedEndpoints.contains(socketParams2.endPointUrl.absoluteString))

        // test params with spaces
        let socketWithSpaces = Socket("ws://localhost:4000/socket/websocket",
                                      paramsClosure: { ["token": "abc 123", "user_id": 1] })
        // absoluteString does not seem to return a string with the params in a deterministic order
        let expectedEndpointsWithSpaces = [
            "ws://localhost:4000/socket/websocket?vsn=2.0.0&token=abc%20123&user_id=1",
            "ws://localhost:4000/socket/websocket?vsn=2.0.0&user_id=1&token=abc%20123"
        ]
        XCTAssert(expectedEndpointsWithSpaces.contains(socketWithSpaces.endPointUrl.absoluteString))
    }

    // constructor deallocates
    func testWeakRetainByPrivateTimer() {
        // Must remain as a weak var in order to deallocate the socket. This tests that the
        // reconnect timer does not old on to the Socket causing a memory leak.
        weak var socket = Socket("http://localhost:4000/socket/websocket")
        XCTAssertNil(socket)
    }

    // params changes dynamically with a closure
    func testParamsClosure() {
        var authToken = "abc123"
        let socket = Socket("ws://localhost:4000/socket/websocket", paramsClosure: { ["token": authToken] })

        XCTAssert(socket.params?["token"] as? String == "abc123")
        authToken = "xyz987"
        XCTAssert(socket.params?["token"] as? String == "xyz987")
    }

    // websocketProtocol returns correct url schemes
    func testSocketURLSchemes() {
        // returns wss when protocol is https
        let socketHttps = Socket("https://example.com/")
        XCTAssert(socketHttps.websocketProtocol == "wss")

        // returns wss when protocol is wss
        let socketWss = Socket("wss://example.com/")
        XCTAssert(socketWss.websocketProtocol == "wss")

        // returns ws when protocol is http
        let socketHttp = Socket("http://example.com/")
        XCTAssert(socketHttp.websocketProtocol == "ws")

        // returns ws when protocol is ws
        let socketWs = Socket("ws://example.com/")
        XCTAssert(socketWs.websocketProtocol == "ws")

        // returns empty if there is no scheme
        let socketNoScheme = Socket("example.com/")
        XCTAssert(socketNoScheme.websocketProtocol.isEmpty)

        // does not append websocket if it already is in the url
        let socketWebsocket = Socket("http://example.com/websocket")
        XCTAssert(socketWebsocket.endPointUrl.absoluteString == "http://example.com/websocket?vsn=2.0.0")

        // appends websocket if it is not in the url
        let socketNoWebsocket = Socket("ws://example.org/chat")
        XCTAssert(socketNoWebsocket.endPointUrl.absoluteString == "ws://example.org/chat/websocket?vsn=2.0.0")
    }
}

extension SocketTests {
    /// establishes websocket connection with endpoint
    func testWebSocketConnection() {
        let socket = createSocketTestsSocket()

        socket.connect()
        XCTAssertNotNil(socket.connection)
    }

    /// test callbacks for connection
    func testWebSocketConnectionCallbacks() async {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createSocketTestsSocket(webSocket: mockWebSocket)

        var open = 0
        socket.socketOpened.sink {
            open += 1
        }
        .store(in: &cancellables)

        var close = 0
        socket.socketClosed.sink {
            close += 1
        }
        .store(in: &cancellables)

        var lastError: Error?
        socket.socketErrored.sink { (error) in
            lastError = error
        }
        .store(in: &cancellables)

        var lastMessage: Message?
        socket.socketRecievedMessage.sink { (message) in
            lastMessage = message
        }
        .store(in: &cancellables)

        mockWebSocket.readyState = .closed
        socket.connect()

        mockWebSocket.delegate?.onOpen()
        XCTAssert(open == 1)

        await mockWebSocket.delegate?.onClose(code: 1000)
        XCTAssert(close == 1)

        await mockWebSocket.delegate?.onError(error: TestError.stub)
        XCTAssertNotNil(lastError)

        let data: [Any] = ["2", "6", "topic", "event", ["response": ["go": true], "status": "ok"]]
        let text = toWebSocketText(data: data)
        await mockWebSocket.delegate?.onMessage(message: text)
        XCTAssert(lastMessage?.payload["go"] as? Bool == true)
    }

    // connect with Websocket does not connect if already connected
    func testOnlyConnectsOnceIfAlreadyConnected() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createSocketTestsSocket(webSocket: mockWebSocket)

        mockWebSocket.readyState = .open

        socket.connect()
        socket.connect()

        XCTAssert(mockWebSocket.connectCallsCount == 1)
    }

    // disconnect removes existing connection
    func testNormalDisconnect() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createSocketTestsSocket(webSocket: mockWebSocket)

        socket.connect()
        socket.disconnect()

        XCTAssertNil(socket.connection)
        XCTAssert(mockWebSocket.disconnectCodeReasonReceivedArguments?.code == Socket.CloseCode.normal.rawValue)
    }

    // disconnect flags the socket as closed cleanly
    func testCleanDisconnect() {
        let socket = createSocketTestsSocket()

        XCTAssert(socket.closeStatus == .unknown)
        socket.disconnect()
        XCTAssert(socket.closeStatus == .clean)
    }

    // disconnect calls callback
    func testDisconnectCallback() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = createSocketTestsSocket(webSocket: mockWebSocket)

        var callCount = 0
        socket.connect()
        socket.disconnect(code: .goingAway) {
            callCount += 1
        }

        XCTAssert(mockWebSocket.disconnectCodeReasonCalled)
        XCTAssertNil(mockWebSocket.disconnectCodeReasonReceivedArguments?.reason)
        XCTAssert(mockWebSocket.disconnectCodeReasonReceivedArguments?.code == Socket.CloseCode.goingAway.rawValue)
        XCTAssert(callCount == 1)
    }

    // disconnect calls onClose for all state callbacks
    func testCallsSocketClosed() {
        let socket = createSocketTestsSocket()
        let expectation = expectation(description: "calls onClose for all state callbacks")

        socket.socketClosed.sink {
            expectation.fulfill()
        }
        .store(in: &cancellables)

        socket.disconnect()
        waitForExpectations(timeout: 3)
    }

    // makeRef returns next message ref and resets to 0 if it hits max int
    func testIncrementalRefs() {
        let socket = Socket("/socket")
        XCTAssert(socket.ref == 0)
        XCTAssert(socket.makeRef() == "1")
        XCTAssert(socket.ref == 1)
        XCTAssert(socket.makeRef() == "2")
        XCTAssert(socket.ref == 2)

        // test resets to 0 if it hits max int
        socket.ref = UInt64.max

        XCTAssert(socket.makeRef() == "0")
        XCTAssert(socket.ref == 0)
    }

    // flushSendBuffer calls callbacks in buffer when connected
    func testFlushSendBuffer() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = Socket("/socket")
        socket.connection = mockWebSocket

        var oneCalled = 0
        socket.sendBuffer.append(("0", { oneCalled += 1 }))
        var twoCalled = 0
        socket.sendBuffer.append(("1", { twoCalled += 1 }))
        let threeCalled = 0

        mockWebSocket.readyState = .open
        socket.flushSendBuffer()
        XCTAssert(oneCalled == 1)
        XCTAssert(twoCalled == 1)
        XCTAssert(threeCalled == 0)
    }

    // flushSendBuffer empties send buffer
    func testEmptySendBuffer() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = Socket("/socket")
        socket.connection = mockWebSocket

        socket.sendBuffer.append((nil, { }))
        mockWebSocket.readyState = .open
        socket.flushSendBuffer()

        XCTAssert(socket.sendBuffer.isEmpty)
    }

    // removeFromSendBuffer removes a callback with a matching ref
    func testRemoveFromSendBuffer() {
        let mockWebSocket = URLSessionTransportMock()
        let socket = Socket("/socket")
        socket.connection = mockWebSocket

        // test removes a callback with a matching ref
        var oneCalled = 0
        socket.sendBuffer.append(("0", { oneCalled += 1 }))
        var twoCalled = 0
        socket.sendBuffer.append(("1", { twoCalled += 1 }))
        let threeCalled = 0

        mockWebSocket.readyState = .open

        socket.removeFromSendBuffer(ref: "0")

        socket.flushSendBuffer()
        XCTAssert(oneCalled == 0)
        XCTAssert(twoCalled == 1)
        XCTAssert(threeCalled == 0)
    }
}
