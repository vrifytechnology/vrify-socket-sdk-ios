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

import XCTest
@testable import SwiftPhoenixClient

/// Tests the FakeTimerQueue that is used in all other tests to verify that
/// the fake timer is behaving as XCTAsserted in all tests to prevent false
/// negatives or positives when writing tests
class FakeTimerQueueTests: XCTestCase {
    func testReset() {
        let queue = FakeTimerQueue()

        var task100msCalled = false
        var task200msCalled = false
        var task300msCalled = false

        queue.queue(timeInterval: 0.1, execute: { task100msCalled = true })
        queue.queue(timeInterval: 0.2, execute: { task200msCalled = true })
        queue.queue(timeInterval: 0.3, execute: { task300msCalled = true })

        queue.tick(0.250)
        XCTAssert(queue.tickTime == 0.250)
        XCTAssert(queue.workItems.count == 1)
        XCTAssert(task100msCalled)
        XCTAssert(task200msCalled)
        XCTAssertFalse(task300msCalled)

        queue.reset()
        XCTAssert(queue.tickTime == 0)
        XCTAssert(queue.workItems.isEmpty)
    }

    func testTriggers() {
        let queue = FakeTimerQueue()
        var task100msCalled = false
        var task200msCalled = false
        var task300msCalled = false

        queue.queue(timeInterval: 0.1, execute: { task100msCalled = true })
        queue.queue(timeInterval: 0.2, execute: { task200msCalled = true })
        queue.queue(timeInterval: 0.3, execute: { task300msCalled = true })

        queue.tick(0.100)
        XCTAssert(queue.tickTime == 0.100)
        XCTAssert(task100msCalled)

        queue.tick(0.100)
        XCTAssert(queue.tickTime == 0.200)
        XCTAssert(task200msCalled)

        queue.tick(0.050)
        XCTAssert(queue.tickTime == 0.250)
        XCTAssertFalse(task300msCalled)
    }

    func testPassedDueTriggers() {
        let queue = FakeTimerQueue()
        var task100msCalled = false
        var task200msCalled = false
        var task300msCalled = false

        queue.queue(timeInterval: 0.1, execute: { task100msCalled = true })
        queue.queue(timeInterval: 0.2, execute: { task200msCalled = true })
        queue.queue(timeInterval: 0.3, execute: { task300msCalled = true })

        queue.tick(0.250)
        XCTAssert(queue.tickTime == 0.250)
        XCTAssert(queue.workItems.count == 1)
        XCTAssert(task100msCalled)
        XCTAssert(task200msCalled)
        XCTAssertFalse(task300msCalled)
    }

    // triggers work that is scheduled for a time that is after tick
    func testTriggersWorkAfterTick() {
        let queue = FakeTimerQueue()
        var task100msCalled = false
        var task200msCalled = false
        var task300msCalled = false

        queue.queue(timeInterval: 0.1, execute: {
            task100msCalled = true

            queue.queue(timeInterval: 0.1, execute: {
                task200msCalled = true
            })
        })

        queue.queue(timeInterval: 0.3, execute: { task300msCalled = true })

        queue.tick(0.250)
        XCTAssert(queue.tickTime == 0.250)
        XCTAssert(task100msCalled)
        XCTAssert(task200msCalled)
        XCTAssertFalse(task300msCalled)
    }

    // does not triggers nested work that is scheduled outside of the tick
    func testNoTriggersOfNestedWorkOutsideTicks() {
        let queue = FakeTimerQueue()
        var task100msCalled = false
        var task200msCalled = false
        var task300msCalled = false

        queue.queue(timeInterval: 0.1, execute: {
            task100msCalled = true

            queue.queue(timeInterval: 0.1, execute: {
                task200msCalled = true

                queue.queue(timeInterval: 0.1, execute: {
                    task300msCalled = true
                })

            })

        })

        queue.tick(0.250)
        XCTAssert(queue.tickTime == 0.250)
        XCTAssert(task100msCalled)
        XCTAssert(task200msCalled)
        XCTAssertFalse(task300msCalled)
    }
}
