import XCTest
@testable import AllSportsScoreboard

final class GameClockTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    func testCountdownIsComputedFromTimestamps() {
        var clock = GameClock(direction: .countDown, length: 600)
        clock.start(at: at(0))
        XCTAssertEqual(clock.remaining(at: at(90.5)), 509.5, accuracy: 1e-9)
        XCTAssertTrue(clock.isRunning)
    }

    func testPauseAndResumeDoNotDrift() {
        var clock = GameClock(direction: .countDown, length: 600)
        clock.start(at: at(0))
        clock.pause(at: at(10))
        // 50 seconds pass while paused.
        XCTAssertEqual(clock.remaining(at: at(60)), 590, accuracy: 1e-9)
        clock.start(at: at(60))
        XCTAssertEqual(clock.remaining(at: at(70)), 580, accuracy: 1e-9)
    }

    func testCountdownClampsAtZeroAndExpires() {
        var clock = GameClock(direction: .countDown, length: 60)
        clock.start(at: at(0))
        XCTAssertFalse(clock.isExpired(at: at(59.9)))
        XCTAssertTrue(clock.isExpired(at: at(60)))
        XCTAssertEqual(clock.remaining(at: at(500)), 0)
        XCTAssertEqual(clock.expiryDate, at(60))
    }

    func testExpiredCountdownCannotRestart() {
        var clock = GameClock(direction: .countDown, length: 30)
        clock.start(at: at(0))
        clock.stopAtLength()
        clock.start(at: at(40))
        XCTAssertFalse(clock.isRunning)
    }

    func testCountUpRunsIntoStoppageTime() {
        var clock = GameClock(direction: .countUp, length: 2_700, runsPastLength: true)
        clock.start(at: at(0))
        XCTAssertEqual(clock.elapsed(at: at(2_820)), 2_820, accuracy: 1e-9)
        XCTAssertTrue(clock.isExpired(at: at(2_820)))
    }

    func testCountUpWithLimitStopsAtLength() {
        var clock = GameClock(direction: .countUp, length: 120)
        clock.start(at: at(0))
        XCTAssertEqual(clock.elapsed(at: at(500)), 120)
    }

    func testAdjustMovesDisplayedTime() {
        var countdown = GameClock(direction: .countDown, length: 600)
        countdown.start(at: at(0))
        countdown.adjust(by: 10, at: at(30))
        XCTAssertEqual(countdown.remaining(at: at(30)), 580, accuracy: 1e-9)
        XCTAssertEqual(countdown.remaining(at: at(40)), 570, accuracy: 1e-9)

        var countUp = GameClock(direction: .countUp, length: 0)
        countUp.adjust(by: 75, at: at(0))
        XCTAssertEqual(countUp.elapsed(at: at(0)), 75)
    }

    func testAdjustNeverExceedsBounds() {
        var clock = GameClock(direction: .countDown, length: 60)
        clock.adjust(by: 600, at: at(0))
        XCTAssertEqual(clock.remaining(at: at(0)), 60)
        clock.adjust(by: -600, at: at(0))
        XCTAssertEqual(clock.remaining(at: at(0)), 0)
    }

    func testClockSurvivesEncoding() throws {
        var clock = GameClock(direction: .countDown, length: 600)
        clock.start(at: at(0))
        let data = try JSONEncoder().encode(clock)
        let decoded = try JSONDecoder().decode(GameClock.self, from: data)
        XCTAssertEqual(decoded.remaining(at: at(100)), 500, accuracy: 0.001)
    }
}

final class TimeFormatTests: XCTestCase {
    func testCountdownRoundsUp() {
        XCTAssertEqual(TimeFormat.clock(600, roundingUp: true, showTenths: false), "10:00")
        XCTAssertEqual(TimeFormat.clock(599.2, roundingUp: true, showTenths: false), "10:00")
        XCTAssertEqual(TimeFormat.clock(0.2, roundingUp: true, showTenths: false), "0:01")
        XCTAssertEqual(TimeFormat.clock(0, roundingUp: true, showTenths: false), "0:00")
    }

    func testTenthsUnderAMinute() {
        XCTAssertEqual(TimeFormat.clock(9.4, roundingUp: true, showTenths: true), "9.4")
        XCTAssertEqual(TimeFormat.clock(9.41, roundingUp: true, showTenths: true), "9.5")
        XCTAssertEqual(TimeFormat.clock(0, roundingUp: true, showTenths: true), "0.0")
        XCTAssertEqual(TimeFormat.clock(59.95, roundingUp: true, showTenths: true), "1:00")
    }

    func testCountUpRoundsDown() {
        XCTAssertEqual(TimeFormat.clock(65.9, roundingUp: false, showTenths: false), "1:05")
        XCTAssertEqual(TimeFormat.clock(2_700, roundingUp: false, showTenths: false), "45:00")
    }

    func testOrdinals() {
        XCTAssertEqual(Ordinal.string(1), "1st")
        XCTAssertEqual(Ordinal.string(2), "2nd")
        XCTAssertEqual(Ordinal.string(3), "3rd")
        XCTAssertEqual(Ordinal.string(4), "4th")
        XCTAssertEqual(Ordinal.string(11), "11th")
        XCTAssertEqual(Ordinal.string(22), "22nd")
    }
}
