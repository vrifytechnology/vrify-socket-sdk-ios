// Generated using Sourcery 1.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

@testable import SwiftPhoenixClient

class PhoenixTransportMock: TransportProtocol {
    var readyState: TransportReadyState {
        get { return underlyingReadyState }
        set(value) { underlyingReadyState = value }
    }
    var underlyingReadyState: TransportReadyState!
    var delegate: TransportProtocol?

    // MARK: - connect

    var connectCallsCount = 0
    var connectCalled: Bool {
        return connectCallsCount > 0
    }
    var connectClosure: (() -> Void)?

    func connect() {
        connectCallsCount += 1
        connectClosure?()
    }

    // MARK: - disconnect

    var disconnectCodeReasonCallsCount = 0
    var disconnectCodeReasonCalled: Bool {
        return disconnectCodeReasonCallsCount > 0
    }
    var disconnectCodeReasonReceivedArguments: (code: Int, reason: String?)?
    var disconnectCodeReasonReceivedInvocations: [(code: Int, reason: String?)] = []
    var disconnectCodeReasonClosure: ((Int, String?) -> Void)?

    func disconnect(code: Int, reason: String?) {
        disconnectCodeReasonCallsCount += 1
        disconnectCodeReasonReceivedArguments = (code: code, reason: reason)
        disconnectCodeReasonReceivedInvocations.append((code: code, reason: reason))
        disconnectCodeReasonClosure?(code, reason)
    }

    // MARK: - send

    var sendDataCallsCount = 0
    var sendDataCalled: Bool {
        return sendDataCallsCount > 0
    }
    var sendDataReceivedData: Data?
    var sendDataReceivedInvocations: [Data] = []
    var sendDataClosure: ((Data) -> Void)?

    func send(data: Data) {
        sendDataCallsCount += 1
        sendDataReceivedData = data
        sendDataReceivedInvocations.append(data)
        sendDataClosure?(data)
    }

}
