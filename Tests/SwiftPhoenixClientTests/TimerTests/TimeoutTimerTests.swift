//
//  TimeoutTimerTests.swift
//  SwiftPhoenixClientTests
//
//  Created by Daniel Rees on 2/10/19.
//

import XCTest
@testable import SwiftPhoenixClient

class TimeoutTimerTests: XCTestCase {
    // scheduleTimeout schedules timeouts, resets the timer, and schedules another timeout
    func testScheduleTimeout() async {
        let fakeClock = FakeTimerQueue()
        let timer = TimeoutTimer()
        timer.queue = fakeClock

        var callbackTimes: [Date] = []
        timer.callback = {
            callbackTimes.append(Date())
        }

        timer.timerCalculation = { tries -> TimeInterval in
            return tries > 2 ? 10.0 : [1.0, 2.0, 5.0][tries - 1]
        }

        await timer.scheduleTimeout()
        fakeClock.tick(1100)
        XCTAssert(timer.tries == 1)

        await timer.scheduleTimeout()
        fakeClock.tick(2100)
        XCTAssert(timer.tries == 2)

        timer.reset()
        await timer.scheduleTimeout()
        fakeClock.tick(1100)
        XCTAssert(timer.tries == 1)
    }

    // scheduleTimeout does not start timer if no interval is provided
    func testNoIntervalTimeoutCreatesNoWorkItem() async {
        let fakeClock = FakeTimerQueue()
        let timer = TimeoutTimer()
        timer.queue = fakeClock

        await timer.scheduleTimeout()
        XCTAssertNil(timer.workItem)
    }

    public func secondsBetweenDates(_ first: Date, _ second: Date) -> Double {
        var diff = first.timeIntervalSince1970 - second.timeIntervalSince1970
        diff = fabs(diff)
        return diff
    }
}
