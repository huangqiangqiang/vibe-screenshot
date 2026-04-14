import Foundation
import Testing
@testable import ScreenshotCore

struct ScreenshotCoreTests {
    @Test
    func timestampUsesExpectedPattern() throws {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 14,
            hour: 12,
            minute: 16,
            second: 30
        )

        let date = try #require(calendar.date(from: components))

        #expect(ScreenshotFileNamer.timestamp(for: date, timeZone: timeZone) == "2026-04-14-12-16-30")
    }

    @Test
    func outputFilenameKeepsLiteralParentheses() throws {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 14,
            hour: 1,
            minute: 2,
            second: 3
        )

        let date = try #require(calendar.date(from: components))
        let outputURL = ScreenshotFileNamer.outputURL(date: date, timeZone: timeZone)

        #expect(outputURL.lastPathComponent == "shot-(2026-04-14-01-02-03).png")
    }
}
