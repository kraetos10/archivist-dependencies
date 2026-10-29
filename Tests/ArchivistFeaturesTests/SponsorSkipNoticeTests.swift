import ArchivistComponents
import Testing

/// The "Skipped by SponsorBlock" banner shows on a skip and clears itself.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SponsorSkipNoticeTests {
    private func waitUntilHidden(_ notice: SponsorSkipNotice) async {
        for _ in 0..<200 where notice.isVisible {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func isHiddenUntilASegmentIsSkipped() {
        #expect(!SponsorSkipNotice(displayDuration: .milliseconds(20)).isVisible)
    }

    @Test func showsOnASkipThenHidesItself() async {
        let notice = SponsorSkipNotice(displayDuration: .milliseconds(30))

        notice.skipped()
        #expect(notice.isVisible)

        await waitUntilHidden(notice)
        #expect(!notice.isVisible)
    }

    @Test func aSecondSkipRestartsTheCountdown() async {
        let notice = SponsorSkipNotice(displayDuration: .milliseconds(150))

        notice.skipped()
        try? await Task.sleep(for: .milliseconds(100))
        notice.skipped()
        try? await Task.sleep(for: .milliseconds(100))
        // 200ms in: the first countdown would have hidden it at 150ms.
        #expect(notice.isVisible)

        await waitUntilHidden(notice)
        #expect(!notice.isVisible)
    }

    @Test func clearHidesItAtOnce() {
        let notice = SponsorSkipNotice(displayDuration: .seconds(60))

        notice.skipped()
        notice.clear()

        #expect(!notice.isVisible)
    }
}
