import Testing
@testable import MurmurCore

@Suite("2.1 Double tap Fn")
struct DoubleTapTests {
    /// Presses and releases Fn at the given times; returns whether the last release fired.
    private func taps(_ times: [(down: Double, up: Double)], detector: inout DoubleTapDetector) -> [Bool] {
        times.map { tap in
            detector.keyDown(at: tap.down)
            return detector.keyUp(at: tap.up)
        }
    }

    @Test func twoQuickTapsFire() {
        var detector = DoubleTapDetector()
        #expect(taps([(0, 0.1), (0.3, 0.4)], detector: &detector) == [false, true])
    }

    @Test func oneTapDoesNothing() {
        var detector = DoubleTapDetector()
        #expect(taps([(0, 0.1)], detector: &detector) == [false])
    }

    @Test func tapsTooFarApartDoNotFire() {
        var detector = DoubleTapDetector()
        #expect(taps([(0, 0.1), (0.8, 0.9)], detector: &detector) == [false, false])
    }

    @Test func aLongHoldIsNotATap() {
        var detector = DoubleTapDetector()
        #expect(taps([(0, 0.6), (0.7, 0.8)], detector: &detector) == [false, false])
    }

    @Test func fnWithAnotherKeyIsNotATap() {
        var detector = DoubleTapDetector()
        detector.keyDown(at: 0)
        detector.otherKey()  // Fn+arrow
        #expect(detector.keyUp(at: 0.1) == false)
        detector.keyDown(at: 0.2)
        #expect(detector.keyUp(at: 0.3) == false)
    }

    @Test func typingBetweenTapsBreaksTheDoubleTap() {
        var detector = DoubleTapDetector()
        detector.keyDown(at: 0)
        #expect(detector.keyUp(at: 0.1) == false)
        detector.otherKey()
        detector.keyDown(at: 0.2)
        #expect(detector.keyUp(at: 0.3) == false)
    }

    @Test func threeTapsFireOnceThenNeedTwoMore() {
        var detector = DoubleTapDetector()
        let results = taps([(0, 0.1), (0.2, 0.3), (0.4, 0.5), (0.6, 0.7)], detector: &detector)
        #expect(results == [false, true, false, true])
    }

    @Test func releaseWithoutPressIsIgnored() {
        var detector = DoubleTapDetector()
        #expect(detector.keyUp(at: 1) == false)
    }
}

@Suite("2.2 On and off")
struct DictationFlowTests {
    @Test func doubleTapStartsThenStops() {
        var flow = DictationFlow()
        #expect(flow.toggle() == .startRecording)
        #expect(flow.phase == .recording)
        #expect(flow.toggle() == .stopAndTranscribe)
        #expect(flow.phase == .transcribing)
        flow.finished()
        #expect(flow.phase == .idle)
    }

    @Test func doubleTapWhileWritingIsIgnored() {
        var flow = DictationFlow()
        _ = flow.toggle()
        _ = flow.toggle()
        #expect(flow.toggle() == .nothing)
        #expect(flow.phase == .transcribing)
    }

    @Test func escapeCancelsOnlyWhileListening() {
        var flow = DictationFlow()
        #expect(flow.cancel() == .nothing)
        _ = flow.toggle()
        #expect(flow.cancel() == .cancelRecording)
        #expect(flow.phase == .idle)
        _ = flow.toggle()
        _ = flow.toggle()
        #expect(flow.cancel() == .nothing)
    }

    @Test func retryOnlyWhenIdle() {
        var flow = DictationFlow()
        #expect(flow.retry() == true)
        #expect(flow.phase == .transcribing)
        #expect(flow.retry() == false)
        flow.finished()
        _ = flow.toggle()
        #expect(flow.retry() == false)
    }
}
