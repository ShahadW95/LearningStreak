import Foundation

// نجمع الهدف الحالي وسجله والأيام القديمة في ملف واحد حتى نحفظها كعملية واحدة.
struct GoalSnapshot: Codable {
    var version = 1
    var goal: LearningGoal?
    var learnedDates: Set<Date> = []
    var frozenDates: Set<Date> = []
    // Optional حتى تبقى ملفات النسخة الأولى قابلة للتحميل بدون فقد البيانات.
    var archivedLearnedDates: Set<Date>? = nil
    var archivedFrozenDates: Set<Date>? = nil
    var timeZoneID: String = TimeZone.current.identifier
}

struct GoalStore {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appendingPathComponent("LearningStreak", isDirectory: true)
            .appendingPathComponent("goal-v1.json")
    }

    // غياب الملف يعني أول استخدام؛ الملف التالف يرمي خطأ ولا يتم استبداله.
    func load() throws -> GoalSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return GoalSnapshot()
        }
        let snapshot = try JSONDecoder().decode(GoalSnapshot.self, from: Data(contentsOf: fileURL))
        guard snapshot.version == 1 else { throw StoreError.unsupportedVersion }
        return snapshot
    }

    // نكتب نسخة كاملة بشكل ذري: لا نظهر نجاحًا إذا فشلت الكتابة.
    func save(_ snapshot: GoalSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // الكتابة الذرية تستبدل الملف القديم بعد اكتمال كتابة الجديد.
        try data.write(to: fileURL, options: .atomic)
    }

    enum StoreError: Error { case unsupportedVersion, invalidData }
}
