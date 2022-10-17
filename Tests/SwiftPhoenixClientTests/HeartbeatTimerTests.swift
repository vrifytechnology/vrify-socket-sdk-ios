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

    func testHeartbeatTimerIsValid() {
        let queue = DispatchQueue(label: "heartbeat.timer.isvalid")
        let timer = HeartbeatTimer(timeInterval: 10, queue: queue)

        XCTAssertFalse(timer.isValid)

        timer.start { _ in }
        XCTAssert(timer.isValid)

        timer.start { _ in }
        timer.stop()
        XCTAssertFalse(timer.isValid)
    }

    func testHeartbeatTimerFiring() {
        let queue = DispatchQueue(label: "heartbeat.timer.firing")
        let timer = HeartbeatTimer(timeInterval: 10, queue: queue)

        var timerCalled = 0
        timer.start { timerCalled += 1 }
        XCTAssert(timerCalled == 0)

        timer.fire()
        XCTAssert(timerCalled == 1)
    }

    func testHeartbeatTimerNotFiringAfterStop() {
        let queue = DispatchQueue(label: "heartbeat.timer.firing")
        let timer = HeartbeatTimer(timeInterval: 10, queue: queue)

        var timerCalled = 0
        timer.start { timerCalled += 1 }
        XCTAssert(timerCalled == 0)
        
        timer.stop()
        timer.fire()
        XCTAssert(timerCalled == 0)
    }

    func testHeartbeatTimerEquatable() {
        let timerA = HeartbeatTimer(timeInterval: 10, queue: queue)
        let timerB = HeartbeatTimer(timeInterval: 10, queue: queue)

        XCTAssert(timerA == timerA)
        XCTAssertFalse(timerA == timerB)
    }
}
