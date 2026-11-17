import Foundation

// خيارات المدة ورصيد التجميد؛ تبقى هنا حتى لا يتكرر تعريفها في ملف GoalDuration القديم.
enum GoalDuration: String, CaseIterable, Codable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var freezeLimit: Int {
        switch self {
        case .week: 2
        case .month: 8
        case .year: 96
        }
    }

    // Calendar يحسب الشهور والسنة الكبيسة بدل افتراض أن كل شهر ثلاثون يومًا.
    func endDate(from start: Date, calendar: Calendar) -> Date {
        let component: Calendar.Component
        let value: Int
        switch self {
        case .week: (component, value) = (.day, 7)
        case .month: (component, value) = (.month, 1)
        case .year: (component, value) = (.year, 1)
        }
        return calendar.date(byAdding: component, value: value, to: start)!
    }
}

// Model بسيط Codable للحفظ؛ id يميز دورة الهدف حتى لو تكرر نفس الاسم.
struct LearningGoal: Identifiable, Codable {
    let id: UUID
    var title: String
    var duration: GoalDuration
    let startDate: Date

    init(title: String, duration: GoalDuration, startDate: Date = Date()) {
        id = UUID()
        self.title = title
        self.duration = duration
        self.startDate = startDate
    }
}

// حالة عرض مشتقة من السجل؛ لا نخزن نسخة إضافية منها حتى لا تتعارض البيانات.
enum DayStatus {
    case learned, frozen, missed, pending
}
