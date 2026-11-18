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
    private(set) var failedOnDay: Date?
    // يوم التعويض المحدد في المهلة؛ ليس اختيارًا حرًا لتعديل أيام قديمة.
    private(set) var recoveryDay: Date?
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
    // فشل أي يوم يقفل الهدف فورًا، وليس عند نهاية الأسبوع/الشهر.
    var hasFailedGoal: Bool { failedOnDay != nil || expiredMissingDay != nil }
    var isGoalFinished: Bool {
        guard let endDate else { return false }
        if hasFailedGoal { return true }
        // آخر يوم أيضًا يستحق مهلة الصباح؛ لا نعلن فشلًا أو نجاحًا وهو ما زال قابلًا للتعويض.
        return referenceDate >= endDate && firstUnrecordedPastDay == nil
    }

    // الأزرار تسجل لليوم الحالي عادة، ولليوم الفائت فقط أثناء التعويض الواضح على الشاشة.
    var activityDate: Date { recoveryDay ?? today }
    var hasLearnedActivityDay: Bool { learnedDates.contains(activityDate) }
    var hasFrozenActivityDay: Bool { frozenDates.contains(activityDate) }
    var recoveryDeadline: Date? { recoveryDay.map { deadline(for: $0) } }
    var hasRecordedRecoveryDay: Bool {
        recoveryDay != nil && (hasLearnedActivityDay || hasFrozenActivityDay)
    }
    private var canEditActivityDay: Bool {
        guard let goal = currentGoal, let endDate else { return false }
        return !loadFailed && !isGoalFinished && activityDate >= goal.startDate && activityDate < endDate
            && referenceDate < deadline(for: activityDate)
    }
    var canLogSelectedDay: Bool { canEditActivityDay }
    var canFreezeSelectedDay: Bool {
        canEditActivityDay && (hasFrozenActivityDay || remainingFreezes > 0)
    }

    // حد المهلة = الثامنة صباح اليوم التالي في تقويم التطبيق.
    // في الرياض: 24 ساعة لليوم + 8 ساعات إضافية. في مناطق DST نتبع اليوم التقويمي والثامنة محليًا.
    func deadline(for day: Date) -> Date {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))!
        return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: nextDay)!
    }

    // نفحص من البداية حتى لا تخفي العودة بعد أيام طويلة أول يوم ضاعت مهلته.
    private var firstUnrecordedPastDay: Date? {
        guard let goal = currentGoal, let endDate else { return nil }
        var day = goal.startDate
        while day < min(today, endDate) {
            if !learnedDates.contains(day) && !frozenDates.contains(day) { return day }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return nil
    }
    private var expiredMissingDay: Date? {
        guard let day = firstUnrecordedPastDay, referenceDate >= deadline(for: day) else { return nil }
        return day
    }

    // الواجهة تستيقظ عند منتصف الليل وعند الثامنة، وتعيد الفحص عند العودة من الخلفية أيضًا.
    var nextRefreshDate: Date {
        let eightAM = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!
        return referenceDate < eightAM ? eightAM : calendar.date(byAdding: .day, value: 1, to: today)!
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
        guard let goal = currentGoal, let endDate, !hasFailedGoal else { return 0 }
        var day = min(today, calendar.date(byAdding: .day, value: -1, to: endDate)!)
        if day == today && status(on: day) == .pending {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while day >= goal.startDate {
            switch status(on: day) {
            case .learned: count += 1
            case .frozen: break
            case .pending where day < today && referenceDate < deadline(for: day): break
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
        if day < today && referenceDate >= deadline(for: day) { return .missed }
        return .pending
    }

    // لا نعتمد على بقاء التطبيق مفتوحًا: نستنتج الفشل من التواريخ المحفوظة عند كل فتح/عملية.
    func refreshDate() {
        referenceDate = now()
        guard !loadFailed else { return }
        if failedOnDay == nil, let day = expiredMissingDay {
            var next = snapshot
            next.failedOnDay = day
            _ = commit(next)
        }
        guard !hasFailedGoal else { recoveryDay = nil; return }
        if let day = recoveryDay, referenceDate >= deadline(for: day) { recoveryDay = nil }
        if recoveryDay == nil, let day = firstUnrecordedPastDay,
           referenceDate < deadline(for: day) {
            recoveryDay = day
        }
    }

    // بعد تعويض أمس، المستخدم ينتقل صراحة إلى اليوم؛ لا نجعل الضغطة التالية تلغي/تسجل يومًا مختلفًا فجأة.
    func continueToToday() {
        refreshDate()
        guard hasRecordedRecoveryDay else { return }
        recoveryDay = nil
    }

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
        next.failedOnDay = nil
        next.learnedDates = []
        next.frozenDates = []
        next.timeZoneID = zone
        _ = commit(next)
    }

    // الضغط على Log يبدّل الحالة: Learned → غير مسجل، أو أي حالة أخرى → Learned.
    // إزالة Freeze تعيد رصيده لأن الرصيد مشتق من عدد الأيام المجمدة، وليس عدادًا منفصلًا.
    func toggleLearned() {
        refreshDate()
        guard canLogSelectedDay else { return }
        var next = snapshot
        if hasLearnedActivityDay {
            next.learnedDates.remove(activityDate)
        } else {
            next.frozenDates.remove(activityDate)
            next.learnedDates.insert(activityDate)
        }
        _ = commit(next)
    }

    // Frozen → غير مسجل، أو Learned/غير مسجل → Frozen بشرط وجود رصيد.
    // نتحقق قبل إزالة Learned: نفاد الرصيد لا يمسح حالة التعلّم المسجلة.
    func toggleFrozen() {
        refreshDate()
        guard canFreezeSelectedDay else { return }
        var next = snapshot
        if hasFrozenActivityDay {
            next.frozenDates.remove(activityDate)
        } else {
            next.learnedDates.remove(activityDate)
            next.frozenDates.insert(activityDate)
        }
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
        next.failedOnDay = nil
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
        next.failedOnDay = nil
        next.learnedDates = []
        next.frozenDates = []
        guard commit(next) else { return false }
        goalTitle = ""
        selectedDuration = .week
        return true
    }

    // MARK: - بيانات الواجهة والتقويم
    // النجاح بعد نهاية المدة، بشرط أن كل الأيام مغطاة ولم يفشل أي يوم بقاعدة المهلة.
    var didMeetGoal: Bool {
        isGoalFinished && !hasFailedGoal && totalDays > 0 && learnedCount + freezeCount == totalDays
    }

    var allLearnedDates: Set<Date> { archivedLearnedDates.union(learnedDates) }
    var allFrozenDates: Set<Date> { archivedFrozenDates.union(frozenDates) }

    // صف الأسبوع للعرض فقط؛ تعديل يوم سابق محصور بيوم التعويض أثناء مهلته.
    var weekDates: [Date] {
        // بعد انتهاء الهدف نعرض أسبوعه الأخير بدل أسبوع جديد فارغ.
        let anchor = failedOnDay ?? expiredMissingDay ?? (isGoalFinished
            ? calendar.date(byAdding: .day, value: -1, to: endDate!)! : today)
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
                     archivedFrozenDates: archivedFrozenDates, failedOnDay: failedOnDay, timeZoneID: timeZoneID)
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
        // الانتقال لهدف جديد يلغي سياق التعويض الخاص بالهدف السابق.
        if currentGoal?.id != saved.goal?.id { recoveryDay = nil }
        currentGoal = saved.goal
        failedOnDay = saved.failedOnDay
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
            guard saved.learnedDates.isEmpty && saved.frozenDates.isEmpty && saved.failedOnDay == nil else {
                throw GoalStore.StoreError.invalidData
            }
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: saved.timeZoneID)!
        let end = goal.duration.endDate(from: goal.startDate, calendar: cal)
        if let day = saved.failedOnDay {
            guard day == cal.startOfDay(for: day), day >= goal.startDate, day < end,
                  !saved.learnedDates.contains(day), !saved.frozenDates.contains(day) else {
                throw GoalStore.StoreError.invalidData
            }
        }
        guard !cleanTitle(goal.title).isEmpty,
              goal.startDate == cal.startOfDay(for: goal.startDate),
              saved.frozenDates.count <= goal.duration.freezeLimit,
              saved.learnedDates.union(saved.frozenDates).allSatisfy({
                  $0 == cal.startOfDay(for: $0) && $0 >= goal.startDate && $0 < end
              }) else { throw GoalStore.StoreError.invalidData }
    }
}
