// مستقل عن App target. نختبر الوقت المحقون في ViewModel، بدون تغيير ساعة الجهاز.
import Foundation

@MainActor
private final class CheckClock {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@main
struct WeekDurationChecks {
    @MainActor
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        func date(_ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ description: String) {
            precondition(condition(), description)
            count += 1
        }
        func fixture(_ name: String, at instant: Date, learned: Set<Date> = [], frozen: Set<Date> = []) throws
        -> (LearningGoalViewModel, CheckClock) {
            let store = GoalStore(fileURL: folder.appendingPathComponent(name + ".json"))
            let goal = LearningGoal(title: "Weekly check", duration: .week, startDate: date(16))
            try store.save(GoalSnapshot(goal: goal, learnedDates: learned, frozenDates: frozen,
                                       timeZoneID: calendar.timeZone.identifier))
            let clock = CheckClock(instant)
            return (LearningGoalViewModel(store: store, now: { clock.now }), clock)
        }
        // الاثنين 16 نوفمبر إلى ما قبل الاثنين 23؛ ليس إلى نهاية الجمعة 20.
        let firstFive = Set((16...20).map { date($0) })
        let (fiveDays, clock) = try fixture("five", at: date(20, hour: 23, minute: 59), learned: firstFive)
        check(fiveDays.totalDays == 7, "Week contains seven calendar days")
        check(fiveDays.endDate == date(23), "End is next Monday, not Friday")
        check(!fiveDays.isGoalFinished && !fiveDays.didMeetGoal, "Five logged days do not complete the goal")
        clock.now = date(21, hour: 12)
        fiveDays.toggleLearned()
        check(fiveDays.learnedDates.contains(date(21)) && fiveDays.learnedCount == 6, "Saturday is a normal learning day")
        check(!fiveDays.didMeetGoal, "Six days do not complete the goal")
        clock.now = date(22, hour: 12)
        fiveDays.toggleLearned()
        check(fiveDays.learnedDates.contains(date(22)) && fiveDays.learnedCount == 7, "Sunday is a normal learning day")
        check(!fiveDays.isGoalFinished, "Wait until seven-day period ends even if all days are recorded")
        clock.now = date(23)
        fiveDays.refreshDate()
        check(fiveDays.didMeetGoal, "Seven fully learned days succeed at the end")

        // Freeze ليس ويكند تلقائيًا: اختاره المستخدم الثلاثاء والخميس في هذه الحالة.
        let learned = Set([16, 18, 20, 21, 22].map { date($0) })
        let frozen = Set([17, 19].map { date($0) })
        let (mixed, mixedClock) = try fixture("mixed", at: date(22, hour: 23, minute: 59), learned: learned, frozen: frozen)
        check(mixed.learnedCount == 5 && mixed.freezeCount == 2 && mixed.totalDays == 7,
              "Five learned plus two explicit freezes still spans seven days")
        check(!mixed.didMeetGoal, "Mixed seven-day goal cannot finish early")
        mixedClock.now = date(23)
        mixed.refreshDate()
        check(mixed.didMeetGoal, "Five learned plus two freezes completes only after all seven calendar days")

        // ترك الويكند بلا تسجيل لا يمنح إجازة تلقائية.
        let (missedWeekend, _) = try fixture("missed", at: date(22, hour: 8), learned: firstFive)
        check(missedWeekend.hasFailedGoal && !missedWeekend.didMeetGoal,
              "Unrecorded Saturday fails on Sunday at 8 AM")
        check(missedWeekend.failedOnDay == date(21), "Failure belongs to the missing Saturday")

        // مهلة اليوم السابع تنتهي الاثنين 8 صباحًا، ولا تحذف يومًا من الأسبوع.
        let firstSix = Set((16...21).map { date($0) })
        let (grace, graceClock) = try fixture("last-grace", at: date(23, hour: 7, minute: 59), learned: firstSix)
        check(!grace.isGoalFinished && grace.activityDate == date(22), "Final Sunday gets the grace period")
        grace.toggleLearned()
        check(grace.didMeetGoal && grace.learnedCount == 7, "Recovering Sunday completes all seven days")
        graceClock.now = date(23, hour: 8)
        grace.refreshDate()
        check(grace.didMeetGoal, "Recovered Sunday stays successful after the cutoff")
        let (expired, _) = try fixture("expired", at: date(23, hour: 8), learned: firstSix)
        check(expired.hasFailedGoal && !expired.didMeetGoal, "Unrecorded seventh day fails at its deadline")
        print("Passed \(count) weekly duration checks.")
    }
}
