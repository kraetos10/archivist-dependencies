import ArchivistNetworking
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PublishedDateTests {
    @Test func parsesInternetDateTime() throws {
        let date = try #require(PublishedDate.date(from: "2024-01-15T10:30:00Z"))
        #expect(date == Date(timeIntervalSince1970: 1_705_314_600))
    }

    @Test func parsesAnOffset() throws {
        let date = try #require(PublishedDate.date(from: "2024-01-15T11:30:00+01:00"))
        #expect(date == Date(timeIntervalSince1970: 1_705_314_600))
    }

    @Test func parsesFractionalSeconds() throws {
        let date = try #require(PublishedDate.date(from: "2024-01-15T10:30:00.250Z"))
        #expect(date.timeIntervalSince1970 == 1_705_314_600.25)
    }

    @Test func parsesADateOnlyValueAsLocalMidnight() throws {
        let date = try #require(PublishedDate.date(from: "2024-01-15"))
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        #expect(parts.year == 2024)
        #expect(parts.month == 1)
        #expect(parts.day == 15)
        #expect(parts.hour == 0)
    }

    @Test(arguments: [nil, "", "   ", "yesterday", "15/01/2024"])
    func rejectsUnparseableValues(raw: String?) {
        #expect(PublishedDate.date(from: raw) == nil)
        #expect(PublishedDate.relative(from: raw) == nil)
    }

    @Test func relativeIsAnchoredToTheGivenNow() throws {
        let now = Date(timeIntervalSince1970: 1_705_314_600)
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let expected = Date.AnchoredRelativeFormatStyle(
            anchor: weekAgo,
            presentation: .named,
            unitsStyle: .wide
        )
        .format(now)
        #expect(PublishedDate.relative(weekAgo, relativeTo: now) == expected)
        #expect(PublishedDate.relative(from: "2024-01-08T10:30:00Z", relativeTo: now) == expected)
    }

    @Test func clockFormatting() {
        #expect(DurationText.clock(seconds: 0) == "0:00")
        #expect(DurationText.clock(seconds: 245) == "4:05")
        #expect(DurationText.clock(seconds: 3723) == "1:02:03")
        #expect(DurationText.clock(seconds: -5) == "0:00")
        #expect(DurationText.clock(seconds: .nan) == "0:00")
    }

    @Test func remainingTimeOnAStartedVideo() {
        let expected = DurationText.abbreviated(seconds: 3_900)
        #expect(!expected.isEmpty)
        #expect(DurationText.abbreviated(seconds: -10) == DurationText.abbreviated(seconds: 0))
    }
}
