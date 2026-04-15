import XCTest
@testable import sealo

/// Exhaustive reducer tests for `AppStore`.
///
/// Every test uses `FakeClock` for deterministic time control. No
/// simulator, no flakes. These are pure-Swift logic tests — the
/// highest-leverage tests in the codebase.
///
/// Coverage matrix:
///   - Normal dive lifecycle (start → tick → end)
///   - Budget exhaustion mid-dive (time limit, dive-count limit)
///   - Shield pre-arming at ~95%
///   - Schedule rollover (midnight / day rolled)
///   - Background relaunch (appBecameActive)
///   - Threshold correction (dead-reckoning snap)
///   - Out-of-range / edge-case inputs
final class AppStoreTests: XCTestCase {

    // MARK: - Helpers

    /// A fixed reference date: 2026-04-12 10:00:00 UTC.
    private static let refDate = Date(timeIntervalSince1970: 1_776_160_800)

    private func makeStore(
        maxMinutes: Int = 60,
        maxDives: Int = 6,
        now: Date = AppStoreTests.refDate
    ) -> (AppStore, FakeClock) {
        let clock = FakeClock(now: now)
        let schedule = Schedule(maxMinutesPerDay: maxMinutes, maxDivesPerDay: maxDives)
        let store = AppStore(schedule: schedule, clock: clock)
        return (store, clock)
    }

    // MARK: - Normal dive lifecycle

    func test_diveStart_createsSession() {
        let (store, _) = makeStore()

        let effects = store.send(.screenTime(.diveStarted))

        XCTAssertTrue(store.state.isDiving)
        XCTAssertNotNil(store.state.currentDive)
        XCTAssertEqual(store.state.dailyBudget.consumedDives, 1)
        XCTAssertEqual(store.state.dailyBudget.dives.count, 1)
        // No shield effect at 1/6 dives.
        XCTAssertEqual(effects, [])
    }

    func test_diveEnd_closesSession() {
        let (store, clock) = makeStore()

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 120) // 2 minutes
        store.send(.screenTime(.diveEnded))

        XCTAssertFalse(store.state.isDiving)
        XCTAssertNil(store.state.currentDive)
        XCTAssertEqual(store.state.dailyBudget.dives.count, 1)
        XCTAssertNotNil(store.state.dailyBudget.dives.first?.endedAt)
        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 120, accuracy: 0.01)
    }

    func test_tick_advancesConsumedTime() {
        let (store, clock) = makeStore()

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 30)
        store.send(.tick)

        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 30, accuracy: 0.01)
    }

    func test_tick_doesNothingWhenNotDiving() {
        let (store, clock) = makeStore()

        clock.advance(by: 300)
        let effects = store.send(.tick)

        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 0)
        XCTAssertEqual(effects, [])
    }

    func test_multipleDives_accumulateCorrectly() {
        let (store, clock) = makeStore()

        // Dive 1: 2 minutes.
        store.send(.screenTime(.diveStarted))
        clock.advance(by: 120)
        store.send(.screenTime(.diveEnded))

        // Dive 2: 3 minutes.
        clock.advance(by: 60) // 1 min gap between dives
        store.send(.screenTime(.diveStarted))
        clock.advance(by: 180)
        store.send(.screenTime(.diveEnded))

        XCTAssertEqual(store.state.dailyBudget.consumedDives, 2)
        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 300, accuracy: 0.01)
        XCTAssertEqual(store.state.dailyBudget.dives.count, 2)
    }

    // MARK: - Budget exhaustion

    func test_exhaustion_byTimeLimit_armsShield() {
        let (store, clock) = makeStore(maxMinutes: 5) // 5 min budget

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 300) // exactly 5 minutes
        let effects = store.send(.tick)

        XCTAssertTrue(store.state.isShieldArmed)
        XCTAssertTrue(store.state.isExhausted)
        XCTAssertEqual(effects, [.armShield])
    }

    func test_exhaustion_byDiveCount_armsShield() {
        let (store, clock) = makeStore(maxMinutes: 999, maxDives: 2)

        // Dive 1.
        store.send(.screenTime(.diveStarted))
        clock.advance(by: 10)
        store.send(.screenTime(.diveEnded))

        // Dive 2 should trigger shield (2/2 dives).
        clock.advance(by: 10)
        let effects = store.send(.screenTime(.diveStarted))

        XCTAssertTrue(store.state.isShieldArmed)
        XCTAssertTrue(store.state.isExhausted)
        XCTAssertEqual(effects, [.armShield])
    }

    func test_exhaustion_blocksNewDives() {
        let (store, clock) = makeStore(maxMinutes: 1, maxDives: 10)

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 60) // 1 min = budget exhausted
        let tickEffects = store.send(.tick)

        // Shield should be armed after the tick that exhausts budget.
        XCTAssertTrue(
            store.state.dailyBudget.isExhausted,
            "Budget should be exhausted after 1 min of 1 min budget"
        )
        XCTAssertTrue(
            store.state.isShieldArmed,
            "Shield should be armed on exhaustion (tick effects: \(tickEffects))"
        )

        store.send(.screenTime(.diveEnded))

        // Try to start a new dive — should be ignored.
        let effects = store.send(.screenTime(.diveStarted))

        XCTAssertFalse(store.state.isDiving)
        XCTAssertTrue(store.state.isShieldArmed)
        // No .armShield effect — shield was already armed from the
        // tick. The reducer correctly deduplicates.
        XCTAssertEqual(effects, [])
    }

    // MARK: - Shield pre-arming (95% threshold)

    func test_preArm_firesAtNinetyFivePercent() {
        let (store, clock) = makeStore(maxMinutes: 100) // 100 min budget

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 95 * 60) // 95 minutes = 95%
        let effects = store.send(.tick)

        XCTAssertTrue(store.state.isShieldArmed)
        XCTAssertFalse(store.state.isExhausted) // not yet exhausted
        XCTAssertEqual(effects, [.armShield])
    }

    func test_preArm_doesNotReFireOnSubsequentTicks() {
        let (store, clock) = makeStore(maxMinutes: 100)

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 95 * 60)
        store.send(.tick) // arms shield

        clock.advance(by: 60) // 96 min
        let effects = store.send(.tick) // should not re-arm

        XCTAssertTrue(store.state.isShieldArmed)
        XCTAssertEqual(effects, []) // no duplicate effect
    }

    // MARK: - Threshold correction (dead reckoning snap)

    func test_thresholdReached_snapsConsumedTime() {
        let (store, clock) = makeStore()

        store.send(.screenTime(.diveStarted))

        // Our dead reckoning says 5 minutes...
        clock.advance(by: 300)
        store.send(.tick)
        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 300, accuracy: 0.01)

        // But the OS says actually 4.5 minutes (we drifted).
        store.send(.screenTime(.thresholdReached(totalMinutes: 4)))

        // Consumed time should snap to the authoritative value.
        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 240, accuracy: 0.01)
    }

    func test_thresholdReached_resetsDeadReckoningAnchor() {
        let (store, clock) = makeStore()

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 300) // 5 min
        store.send(.screenTime(.thresholdReached(totalMinutes: 5)))

        // Now advance 2 more minutes.
        clock.advance(by: 120)
        store.send(.tick)

        // Should be 5min (from threshold) + 2min (from tick) = 7min.
        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 420, accuracy: 0.01)
    }

    // MARK: - Day rollover

    func test_dayRolled_resetsBudget() {
        let (store, clock) = makeStore()

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 600) // 10 min
        store.send(.tick)
        store.send(.screenTime(.diveEnded))

        // Roll the day.
        clock.advance(by: 3600)
        let effects = store.send(.dayRolled)

        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 0)
        XCTAssertEqual(store.state.dailyBudget.consumedDives, 0)
        XCTAssertEqual(store.state.dailyBudget.dives.count, 0)
        XCTAssertFalse(store.state.isDiving)
        XCTAssertEqual(effects, []) // shield wasn't armed, no disarm
    }

    func test_dayRolled_disarmsShieldIfArmed() {
        let (store, clock) = makeStore(maxMinutes: 1)

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 60) // exhaust budget
        store.send(.tick)

        XCTAssertTrue(store.state.isShieldArmed)

        clock.advance(by: 3600)
        let effects = store.send(.dayRolled)

        XCTAssertFalse(store.state.isShieldArmed)
        XCTAssertTrue(effects.contains(.disarmShield))
    }

    func test_dayRolled_endsInProgressDive() {
        let (store, clock) = makeStore()

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 300)

        XCTAssertTrue(store.state.isDiving)

        clock.advance(by: 3600)
        store.send(.dayRolled)

        XCTAssertFalse(store.state.isDiving)
        XCTAssertNil(store.state.currentDive)
    }

    // MARK: - Background relaunch

    func test_appBecameActive_detectsDayRoll() {
        let (store, clock) = makeStore()

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 120)
        store.send(.screenTime(.diveEnded))

        // Simulate overnight background: advance 14 hours.
        clock.advance(by: 14 * 3600)
        let effects = store.send(.appBecameActive)

        // Should have rolled the day.
        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 0)
        XCTAssertEqual(store.state.dailyBudget.consumedDives, 0)
        // No shield effect unless it was armed.
        XCTAssertEqual(effects, [])
    }

    func test_appBecameActive_advancesTimeIfDiving() {
        let (store, clock) = makeStore()

        store.send(.screenTime(.diveStarted))

        // App was backgrounded for 2 minutes (same day).
        clock.advance(by: 120)
        store.send(.appBecameActive)

        XCTAssertEqual(store.state.dailyBudget.consumedSeconds, 120, accuracy: 0.01)
        XCTAssertTrue(store.state.isDiving)
    }

    // MARK: - Schedule changes

    func test_scheduleChanged_updatesSchedule() {
        let (store, _) = makeStore()

        let newSchedule = Schedule(maxMinutesPerDay: 30, maxDivesPerDay: 3)
        store.send(.scheduleChanged(newSchedule))

        XCTAssertEqual(store.state.schedule, newSchedule)
    }

    // MARK: - Edge cases

    func test_duplicateDiveStart_isIgnored() {
        let (store, _) = makeStore()

        store.send(.screenTime(.diveStarted))
        store.send(.screenTime(.diveStarted)) // duplicate

        XCTAssertEqual(store.state.dailyBudget.consumedDives, 1)
        XCTAssertEqual(store.state.dailyBudget.dives.count, 1)
    }

    func test_diveEndWithoutStart_isIgnored() {
        let (store, _) = makeStore()

        store.send(.screenTime(.diveEnded)) // no dive in progress

        XCTAssertFalse(store.state.isDiving)
        XCTAssertEqual(store.state.dailyBudget.consumedDives, 0)
    }

    func test_fillFraction_decreasesCorrectly() {
        let (store, clock) = makeStore(maxMinutes: 10) // 10 min budget

        XCTAssertEqual(store.state.fillFraction, 1.0, accuracy: 0.01)

        store.send(.screenTime(.diveStarted))
        clock.advance(by: 300) // 5 min = 50%
        store.send(.tick)

        XCTAssertEqual(store.state.fillFraction, 0.5, accuracy: 0.01)

        clock.advance(by: 300) // 10 min = 0%
        store.send(.tick)

        XCTAssertEqual(store.state.fillFraction, 0.0, accuracy: 0.01)
    }
}
