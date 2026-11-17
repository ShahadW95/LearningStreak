import Foundation
import Observation

@MainActor
@Observable
final class LearningGoalViewModel {
    // MARK: - مدخلات الشاشة والبيانات المحفوظة
    // الواجهات تعدّل مدخلات Onboarding فقط؛ تغيير البيانات المسجلة يمر عبر الدوال.
    var goalTitle = ""
    var selectedDuration: GoalDuration = .week
    private(set) var currentGoal: LearningGoal?
    private(set) var learnedDates: Set<Date> = []
    private(set) var frozenDates: Set<Date> = []
    private(set) var archivedLearnedDates: Set<Date> = []
    private(set) var archivedFrozenDates: Set<Date> = []
    private(set) var loadFailed = false
    var errorMessage: String?

    // أدوات ثابتة لا تُعرض في الواجهة؛ now قابل للاستبدال بساعة الاختبار بدون تغيير ساعة الجهاز.
    @ObservationIgnored private let store: GoalStore
    @ObservationIgnored private let now: () -> Date
    private var timeZoneID = TimeZone.current.identifier
    // تاريخ قابل للملاحظة حتى تتحدث الشاشة عند منتصف الليل أو العودة من الخلفية.
    private var referenceDate: Date

    // تحميل البيانات مرة واحدة عند إنشاء المالك؛ إعادة رسم الواجهة لا تعيد إنشاء هذا الكائن.
    init(store: GoalStore = GoalStore(), now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.now = now
        referenceDate = now()
        load()
    }

    // MARK: - قواعد اليوم والمدة
    // تقويم ميلادي ثابت للبيانات؛ بداية الأسبوع الأحد مثل المرجع.
    var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.firstWeekday = 1
        result.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return result
    }

    var today: Date { calendar.startOfDay(for: referenceDate) }
    var canStartLearning: Bool {
        currentGoal == nil && !loadFailed && !cleanTitle(goalTitle).isEmpty
    }
    var learnedCount: Int { learnedDates.count }
    var freezeCount: Int { frozenDates.count }
    var freezeLimit: Int { (currentGoal?.duration ?? selectedDuration).freezeLimit }
    var remainingFreezes: Int { max(0, freezeLimit - freezeCount) }
    var hasLearnedToday: Bool { learnedDates.contains(today) }
    var hasFrozenToday: Bool { frozenDates.contains(today) }
    // نهاية المدة غير مشمولة بالتسجيل؛ آخر يوم مسموح هو اليوم اللي قبلها.
    var endDate: Date? {
        guard let goal = currentGoal else { return nil }
        return goal.duration.endDate(from: goal.startDate, calendar: calendar)
    }
    var isGoalFinished: Bool { endDate.map { today >= $0 } ?? false }
    var isActiveToday: Bool {
        guard let goal = currentGoal, let endDate else { return false }
        return !loadFailed && today >= goal.startDate && today < endDate
    }
    // شروط الأزرار للعرض، وتُستخدم مرة ثانية داخل العمليات لمنع تجاوز القواعد.
    var canLogToday: Bool { isActiveToday && !hasLearnedToday }
    var canFreezeToday: Bool {
        isActiveToday && !hasLearnedToday && !hasFrozenToday && remainingFreezes > 0
    }
    var totalDays: Int {
        guard let goal = currentGoal, let endDate else { return 0 }
        return calendar.dateComponents([.day], from: goal.startDate, to: endDate).day ?? 0
    }
    var daysRemaining: Int {
        guard let endDate else { return 0 }
        return max(0, calendar.dateComponents([.day], from: today, to: endDate).day ?? 0)
    }

    // MARK: - حساب الستريك
    // نرجع من آخر يوم للخلف: Learned يزيد العدد، Freeze يسمح بالاستمرار، واليوم الفائت يوقفه.
    // TODO(decision): Freeze يحافظ على الاتصال لكنه لا يزيد عدد أيام التعلّم.
    // اليوم الحالي غير المسجل لا يكسر ستريك أمس قبل انتهاء اليوم.
    var currentStreak: Int {
        guard let goal = currentGoal, let endDate else { return 0 }
        var day = min(today, calendar.date(byAdding: .day, value: -1, to: endDate)!)
        if day == today && status(on: day) == .pending {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while day >= goal.startDate {
            switch status(on: day) {
            case .learned: count += 1
            case .frozen: break
            case .missed, .pending: return count
            }
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    // أيام الهدف الحالي المنقضية فقط، مفيدة للاختبارات وحساب النتائج.
    var historyDates: [Date] {
        guard let goal = currentGoal, let endDate else { return [] }
        let lastDay = min(today, calendar.date(byAdding: .day, value: -1, to: endDate)!)
        guard lastDay >= goal.startDate else { return [] }
        var dates: [Date] = []
        var day = goal.startDate
        while day <= lastDay {
            dates.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return dates.reversed()
    }

    func status(on date: Date) -> DayStatus {
        let day = calendar.startOfDay(for: date)
        if learnedDates.contains(day) { return .learned }
        if frozenDates.contains(day) { return .frozen }
        return day < today ? .missed : .pending
    }

    func refreshDate() { referenceDate = now() }

    // ننشئ هدفًا فقط إذا الاسم صالح وما فيه هدف حالي؛ الحفظ هو اللي يثبت الإنشاء.
    func startLearning() {
        refreshDate()
        guard canStartLearning else { return }
        // TODO(decision): حد اليوم ثابت بمنطقة أول هدف، ويبقى ثابتًا لسجله والأهداف اللاحقة.
        // تغيير منطقة الجهاز أثناء السفر لا يعيد توزيع الأيام المسجلة.
        let zone = archivedLearnedDates.isEmpty && archivedFrozenDates.isEmpty
            ? TimeZone.current.identifier : timeZoneID
        var startCalendar = Calendar(identifier: .gregorian)
        startCalendar.timeZone = TimeZone(identifier: zone) ?? .current
        let goal = LearningGoal(title: cleanTitle(goalTitle), duration: selectedDuration,
                                startDate: startCalendar.startOfDay(for: now()))
        var next = snapshot
        next.goal = goal
        next.learnedDates = []
        next.frozenDates = []
        next.timeZoneID = zone
        _ = commit(next)
    }

    // نحدّث التاريخ ثم نتحقق من القاعدة هنا، وليس فقط بتعطيل زر الواجهة.
    func logLearnedToday() {
        refreshDate()
        guard canLogToday else { return }
        var next = snapshot
        // التعلّم يستبدل Freeze لليوم نفسه ويرجّع رصيده؛ لا نسجل الحالتين معًا.
        next.frozenDates.remove(today)
        next.learnedDates.insert(today)
        _ = commit(next)
    }

    // Freeze لليوم الحالي فقط، بشرط وجود رصيد وعدم تسجيل التعلّم مسبقًا.
    func freezeToday() {
        refreshDate()
        guard canFreezeToday else { return }
        var next = snapshot
        next.frozenDates.insert(today)
        _ = commit(next)
    }

    // MARK: - تحديث الهدف وبدء دورة جديدة
    // حسب المرجع: Update يبدأ هدفًا جديدًا بعد تأكيد من الواجهة.
    // نؤرشف الأيام القديمة للتقويم ونصفّر عدادات الهدف؛ الإلغاء لا يستدعي هذه الدالة.
    @discardableResult
    func updateGoal(title: String, duration: GoalDuration) -> Bool {
        refreshDate()
        guard currentGoal != nil, !loadFailed else { return false }
        let title = cleanTitle(title)
        guard !title.isEmpty else { errorMessage = "Enter a learning goal."; return false }
        let goal = LearningGoal(title: title, duration: duration, startDate: today)
        var next = snapshot
        next.archivedLearnedDates = allLearnedDates
        next.archivedFrozenDates = allFrozenDates
        next.goal = goal
        next.learnedDates = []
        next.frozenDates = []
        return commit(next)
    }

    // الرجوع إلى Onboarding لا يحذف التاريخ العام؛ فقط ننهي الهدف الحالي.
    @discardableResult
    func resetGoal() -> Bool {
        guard !loadFailed else { return false }
        var next = snapshot
        next.archivedLearnedDates = allLearnedDates
        next.archivedFrozenDates = allFrozenDates
        next.goal = nil
        next.learnedDates = []
        next.frozenDates = []
        guard commit(next) else { return false }
        goalTitle = ""
        selectedDuration = .week
        return true
    }

    // MARK: - بيانات الواجهة والتقويم
    // نتيجة الهدف ليست مجرد انتهاء الوقت: نتأكد أن كل يوم كان Learned أو Frozen.
    // TODO(decision): هذا معيار مبدئي لأن الصور لا تحدد الحد المطلوب لأيام التعلّم صراحة.
    var didMeetGoal: Bool {
        isGoalFinished && learnedCount + freezeCount == totalDays
    }

    var allLearnedDates: Set<Date> { archivedLearnedDates.union(learnedDates) }
    var allFrozenDates: Set<Date> { archivedFrozenDates.union(frozenDates) }

    // صف الأسبوع للعرض فقط؛ تسجيل النشاط دائمًا لليوم الحالي.
    var weekDates: [Date] {
        // بعد انتهاء الهدف نعرض أسبوعه الأخير بدل أسبوع جديد فارغ.
        let anchor = isGoalFinished ? calendar.date(byAdding: .day, value: -1, to: endDate!)! : today
        let weekday = calendar.component(.weekday, from: anchor)
        let sunday = calendar.date(byAdding: .day, value: -(weekday - 1), to: anchor)!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: sunday)! }
    }

    // نعرض أشهر السجل حتى الشهر الحالي، ثم يختار ScrollView موضع الشهر الحالي عند الفتح.
    var calendarMonths: [Date] {
        let firstDate = (allLearnedDates.union(allFrozenDates).union([currentGoal?.startDate ?? today])).min() ?? today
        let first = calendar.dateInterval(of: .month, for: min(firstDate, today))!.start
        let last = calendar.dateInterval(of: .month, for: today)!.start
        var result: [Date] = []
        var month = first
        while month <= last {
            result.append(month)
            month = calendar.date(byAdding: .month, value: 1, to: month)!
        }
        return result
    }

    // تقويم السجل يضم الأهداف السابقة. إذا تعلمتِ وجمّدتِ ضمن هدفين بنفس اليوم، نعرض Learned.
    func historyStatus(on date: Date) -> DayStatus {
        let day = calendar.startOfDay(for: date)
        if allLearnedDates.contains(day) { return .learned }
        if allFrozenDates.contains(day) { return .frozen }
        return day < today ? .missed : .pending
    }

    // التحميل يسترجع snapshot ثم يتحقق من توافق بياناته قبل عرضها.
    func load() {
        do {
            let saved = try store.load()
            try validate(saved)
            apply(saved)
            loadFailed = false
            errorMessage = nil
            refreshDate()
        } catch {
            // لا نستبدل ملفًا لا نستطيع قراءته بهدف فارغ؛ نوقف التعديل لحماية البيانات.
            loadFailed = true
            errorMessage = "Your saved data couldn't be opened. It has not been replaced. Try again."
        }
    }

    // MARK: - الحفظ والاسترجاع
    // نسخة من الحالة الحالية للتعديل عليها قبل حفظها؛ لا نغيّر المعروض إلا بعد نجاح الكتابة.
    private var snapshot: GoalSnapshot {
        GoalSnapshot(goal: currentGoal, learnedDates: learnedDates,
                     frozenDates: frozenDates, archivedLearnedDates: archivedLearnedDates,
                     archivedFrozenDates: archivedFrozenDates, timeZoneID: timeZoneID)
    }

    // نحفظ أولًا ثم نعرض النتيجة؛ عند الفشل تبقى البيانات السابقة ورسالة تسمح بالمحاولة.
    private func commit(_ next: GoalSnapshot) -> Bool {
        guard !loadFailed else { return false }
        do {
            try store.save(next)
            apply(next)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Couldn't save your change. Your previous data is still shown. Please try again."
            return false
        }
    }

    private func apply(_ saved: GoalSnapshot) {
        currentGoal = saved.goal
        learnedDates = saved.learnedDates
        frozenDates = saved.frozenDates
        archivedLearnedDates = saved.archivedLearnedDates ?? []
        archivedFrozenDates = saved.archivedFrozenDates ?? []
        timeZoneID = saved.timeZoneID
    }

    private func cleanTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // نفحص تناقضات البيانات: تداخل الحالات، تواريخ خارج الهدف، أو رصيد يتجاوز الحد.
    private func validate(_ saved: GoalSnapshot) throws {
        guard TimeZone(identifier: saved.timeZoneID) != nil,
              saved.learnedDates.isDisjoint(with: saved.frozenDates) else {
            throw GoalStore.StoreError.invalidData
        }
        var archiveCalendar = Calendar(identifier: .gregorian)
        archiveCalendar.timeZone = TimeZone(identifier: saved.timeZoneID)!
        guard (saved.archivedLearnedDates ?? []).union(saved.archivedFrozenDates ?? []).allSatisfy({
            $0 == archiveCalendar.startOfDay(for: $0)
        }) else { throw GoalStore.StoreError.invalidData }
        guard let goal = saved.goal else {
            guard saved.learnedDates.isEmpty && saved.frozenDates.isEmpty else {
                throw GoalStore.StoreError.invalidData
            }
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: saved.timeZoneID)!
        let end = goal.duration.endDate(from: goal.startDate, calendar: cal)
        guard !cleanTitle(goal.title).isEmpty,
              goal.startDate == cal.startOfDay(for: goal.startDate),
              saved.frozenDates.count <= goal.duration.freezeLimit,
              saved.learnedDates.union(saved.frozenDates).allSatisfy({
                  $0 == cal.startOfDay(for: $0) && $0 >= goal.startDate && $0 < end
              }) else { throw GoalStore.StoreError.invalidData }
    }
}
