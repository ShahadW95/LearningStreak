import SwiftUI

// تقويم للعرض فقط: لا يوجد date selection أو تعديل سجل عند الضغط على اليوم.
// Calendar من Foundation يحسب الشهور والأيام، وSwiftUI مسؤول عن ترتيبها وتلوينها فقط.
struct HistoryView: View {
    let viewModel: LearningGoalViewModel

    var body: some View {
        VStack(spacing: 0) {
            StreakPageHeader(title: "Activities")
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.calendarMonths, id: \.self) { month in
                            CalendarMonthView(month: month, viewModel: viewModel)
                                .id(month)
                            Divider().padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear {
                    // نفتح عند الشهر الحالي؛ التمرير للأعلى يكشف سجل الشهور السابقة.
                    if let month = viewModel.calendarMonths.last {
                        proxy.scrollTo(month, anchor: .top)
                    }
                }
            }
        }
        .background(.black)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct CalendarMonthView: View {
    let month: Date
    let viewModel: LearningGoalViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    // عدد الخانات الفارغة قبل اليوم الأول يحافظ على محاذاة الأحد حتى السبت.
    private var offset: Int { viewModel.calendar.component(.weekday, from: month) - 1 }
    private var dayCount: Int { viewModel.calendar.range(of: .day, in: .month, for: month)!.count }
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = viewModel.calendar
        formatter.timeZone = viewModel.calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthTitle).font(.subheadline.weight(.semibold)).padding(.top, 20)
            HStack(spacing: 0) {
                ForEach(["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"], id: \.self) { day in
                    Text(day).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<(offset + dayCount), id: \.self) { index in
                    if index < offset {
                        Color.clear.frame(height: 36).accessibilityHidden(true)
                    } else {
                        let date = viewModel.calendar.date(byAdding: .day, value: index - offset, to: month)!
                        CalendarDayCell(date: date, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

// نفس خلية اليوم يستخدمها صف الأسبوع وتقويم الأشهر، حتى تكون ألوان الحالات متطابقة.
struct CalendarDayCell: View {
    let date: Date
    let viewModel: LearningGoalViewModel
    var currentGoalOnly = false

    private var status: DayStatus {
        currentGoalOnly ? viewModel.status(on: date) : viewModel.historyStatus(on: date)
    }
    private var isToday: Bool { viewModel.calendar.isDate(date, inSameDayAs: viewModel.today) }
    private var highlightToday: Bool {
        isToday && status != .frozen && (status != .learned || !currentGoalOnly)
    }
    private var fill: Color {
        if highlightToday { return StreakStyle.orange }
        switch status {
        case .learned: return StreakStyle.orange.opacity(0.14)
        case .frozen: return StreakStyle.cyan.opacity(0.14)
        case .missed, .pending: return .clear
        }
    }
    private var ink: Color {
        if highlightToday { return .white }
        switch status {
        case .learned: return StreakStyle.orange
        case .frozen: return StreakStyle.cyan
        case .missed, .pending: return .white
        }
    }
    private var statusName: String {
        switch status {
        case .learned: "Learned"
        case .frozen: "Frozen"
        case .missed: "No activity logged"
        case .pending: isToday ? "Today, not logged" : "No activity logged"
        }
    }

    var body: some View {
        Text("\(viewModel.calendar.component(.day, from: date))")
            .font(.body).foregroundStyle(ink)
            .frame(width: 36, height: 36).background(fill, in: Circle())
            .frame(maxWidth: .infinity)
            // VoiceOver يقرأ الحالة بالكلام، فلا يعتمد فهم اللون وحده.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(date, format: .dateTime.day().month(.wide).year()))
            .accessibilityValue(statusName)
    }
}
