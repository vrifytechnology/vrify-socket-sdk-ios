//
//  HeartbeatTimerTests.swift
//  SwiftPhoenixClientTests
//
//  Created by Daniel Rees on 8/24/21.
//  Copyright © 2021 SwiftPhoenixClient. All rights reserved.
//

import XCTest
@testable import SwiftPhoenixClient

class HeartbeatTimerTests: XCTestCase {
    // heartbeat timer returns false if is not started and returns true if the timer has started
    func testHeartbeatTimerIsValid() {
        let queue = DispatchQueue(label: "heartbeat.timer.isvalid")
        let timer = HeartbeatTimer(timeInterval: 10, queue: queue)

        XCTAssertFalse(timer.isValid)

        timer.start { }
        XCTAssert(timer.isValid)

        timer.start { }
        timer.stop()
        XCTAssertFalse(timer.isValid)
    }

    // heartbeat timer fire calls the event handler
    func testHeartbeatTimerFiring() {
        let queue = DispatchQueue(label: "heartbeat.timer.firing")
        let timer = HeartbeatTimer(timeInterval: 10, queue: queue)

        var timerCalled = 0
        timer.start { timerCalled += 1 }
        XCTAssert(timerCalled == 0)

        timer.fire()
        XCTAssert(timerCalled == 1)
    }

    // heartbeat timer fire does not call event handler if stopped
    func testHeartbeatTimerNotFiringAfterStop() {
        let queue = DispatchQueue(label: "heartbeat.timer.notfiring")
        let timer = HeartbeatTimer(timeInterval: 10, queue: queue)

        var timerCalled = 0
        timer.start { timerCalled += 1 }
        XCTAssert(timerCalled == 0)

        timer.stop()
        timer.fire()
        XCTAssert(timerCalled == 0)
    }

    // heartbeat timer equatable equates different timers correctly
    func testHeartbeatTimerEquatable() {
        let queue = DispatchQueue(label: "heartbeat.timer.timeequatable")
        let timerA = HeartbeatTimer(timeInterval: 10, queue: queue)
        let timerB = HeartbeatTimer(timeInterval: 10, queue: queue)

        XCTAssert(timerA == timerA)
        XCTAssertFalse(timerA == timerB)
    }
}
