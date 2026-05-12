import XCTest
@testable import BulkAIEngine

final class CalendarDayTests: XCTestCase {
    func testDaysSince_sameDay_isZero() {
        let day = CalendarDay(year: 2026, month: 5, day: 12)
        XCTAssertEqual(day.daysSince(day, in: .bulkAI), 0)
    }

    func testDaysSince_consecutive_isOne() {
        let a = CalendarDay(year: 2026, month: 5, day: 12)
        let b = CalendarDay(year: 2026, month: 5, day: 13)
        XCTAssertEqual(b.daysSince(a, in: .bulkAI), 1)
        XCTAssertEqual(a.daysSince(b, in: .bulkAI), -1)
    }

    func testDaysSince_acrossMonth() {
        let a = CalendarDay(year: 2026, month: 1, day: 30)
        let b = CalendarDay(year: 2026, month: 2, day: 5)
        XCTAssertEqual(b.daysSince(a, in: .bulkAI), 6)
    }

    func testDaysSince_acrossYear() {
        let a = CalendarDay(year: 2025, month: 12, day: 28)
        let b = CalendarDay(year: 2026, month: 1, day: 3)
        XCTAssertEqual(b.daysSince(a, in: .bulkAI), 6)
    }

    func testAddingDays_positive() {
        let day = CalendarDay(year: 2026, month: 5, day: 12)
        let plus10 = day.adding(days: 10, in: .bulkAI)
        XCTAssertEqual(plus10, CalendarDay(year: 2026, month: 5, day: 22))
    }

    func testAddingDays_negativeAcrossMonth() {
        let day = CalendarDay(year: 2026, month: 5, day: 5)
        let minus10 = day.adding(days: -10, in: .bulkAI)
        XCTAssertEqual(minus10, CalendarDay(year: 2026, month: 4, day: 25))
    }

    func testComparable() {
        let a = CalendarDay(year: 2026, month: 1, day: 1)
        let b = CalendarDay(year: 2026, month: 1, day: 2)
        let c = CalendarDay(year: 2026, month: 2, day: 1)
        XCTAssertTrue(a < b)
        XCTAssertTrue(b < c)
        XCTAssertFalse(c < a)
    }

    func testRoundTripDateConstructor() {
        let day = CalendarDay(year: 2026, month: 5, day: 12)
        let date = day.startOfDay(in: .bulkAI)
        let roundTrip = CalendarDay(date: date, calendar: .bulkAI)
        XCTAssertEqual(day, roundTrip)
    }
}
