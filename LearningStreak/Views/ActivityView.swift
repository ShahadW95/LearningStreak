import SwiftUI

// شاشة النشاط تجمع ملخص الأسبوع والعدادات وإجراء اليوم؛ لا تعدّل البيانات مباشرة.
struct ActivityView: View {
    let viewModel: LearningGoalViewModel

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        weekStrip.padding(.top, 12)
                        counters.padding(.top, 16)
                        if viewModel.isGoalFinished {
                            resultContent.padding(.top, 50)
                        } else {
                            Spacer(minLength: 32)
                            learnedButton(diameter: min(geometry.size.width - 88, 280))
                            Spacer(minLength: 32)
                            freezeControls
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(.black)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // الزران ظاهرين أعلى الشاشة مثل المرجع؛ التقويم صفحة، وتعديل الهدف صفحة مستقلة.
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Activity").font(.largeTitle.bold())
                Text(viewModel.today, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                NavigationLink { HistoryView(viewModel: viewModel) } label: {
                    headerIcon("calendar")
                }.accessibilityLabel("Open activity calendar")
                if let goal = viewModel.currentGoal {
                    NavigationLink { EditGoalView(viewModel: viewModel, goal: goal) } label: {
                        headerIcon("target")
                    }.accessibilityLabel("Change learning goal")
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func headerIcon(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.title3).foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Color(white: 0.08), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.25)))
    }

    // نفس مكوّن تلوين اليوم مستخدم هنا وفي شاشة التقويم؛ الصف ليس لاختيار يوم التسجيل.
    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.weekDates.enumerated()), id: \.element) { index, date in
                VStack(spacing: 8) {
                    Text(["S", "M", "T", "W", "T", "F", "S"][index])
                        .font(.caption2)
                    CalendarDayCell(date: date, viewModel: viewModel, currentGoalOnly: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("This week")
    }

    // Learned وFrozen عدّادان للهدف الحالي، وليس currentStreak ولا مجموع الأهداف القديمة.
    private var counters: some View {
        HStack(spacing: 12) {
            counter(symbol: "flame.fill", count: viewModel.learnedCount,
                    title: "Learned", color: StreakStyle.orange)
            counter(symbol: "snowflake", count: viewModel.freezeCount,
                    title: "Frozen", color: StreakStyle.cyan)
        }
    }

    private func counter(symbol: String, count: Int, title: String, color: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
            Text("\(count) \(count == 1 ? "day" : "days")").font(.subheadline.weight(.semibold))
            Text(title).font(.caption2)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color(white: 0.035), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.22)))
        .accessibilityElement(children: .combine)
    }

    // الزر الدائري يتعطل بعد التسجيل. وجود Freeze لا يمنع التعلّم: يستبدله ويرجع رصيده.
    private func learnedButton(diameter: CGFloat) -> some View {
        Button { viewModel.logLearnedToday() } label: {
            Text(viewModel.hasLearnedToday ? "Logged as Learned" : "Log as Learned")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(viewModel.hasLearnedToday ? Color.secondary : Color.white)
                .multilineTextAlignment(.center).padding(24)
                .frame(width: diameter, height: diameter)
                .background(viewModel.hasLearnedToday ? Color(white: 0.09) : StreakStyle.orange, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(viewModel.hasLearnedToday ? 0.15 : 0.55)))
        }
        .buttonStyle(.plain).disabled(!viewModel.canLogToday)
        .accessibilityHint("Records learning for today only")
    }

    // حالات الزر: متاح، جُمّد اليوم، الرصيد انتهى، أو تم التعلّم. المنع موجود بالـ ViewModel أيضًا.
    private var freezeControls: some View {
        VStack(spacing: 14) {
            Button { viewModel.freezeToday() } label: {
                Text(viewModel.hasFrozenToday ? "Frozen for a day" : "Freeze for a day")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(viewModel.canFreezeToday ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(viewModel.canFreezeToday ? StreakStyle.cyan : Color(white: 0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
            }
            .buttonStyle(.plain).disabled(!viewModel.canFreezeToday)
            Text("\(viewModel.freezeCount) out of \(viewModel.freezeLimit) Freezes used")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 36)
    }

    // نهاية الفترة لها حالتان مثل المرجع؛ Set a goal يسمح باختيار نفس الهدف أو تغييره.
    private var resultContent: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.didMeetGoal ? "hands.clap.fill" : "xmark.seal")
                .font(.system(size: 44)).foregroundStyle(StreakStyle.orange)
                .padding(.bottom, 16)
            Text(viewModel.didMeetGoal ? "Well done!" : "You didn't reach your goal this time.")
                .font(.headline).multilineTextAlignment(.center)
            Text(viewModel.didMeetGoal ? "Ready for your next goal?" : "Want to set another goal?")
                .font(.subheadline).foregroundStyle(.secondary)
            if let goal = viewModel.currentGoal {
                NavigationLink {
                    EditGoalView(viewModel: viewModel, goal: goal, isNewCycle: true)
                } label: {
                    Label("Set a goal", systemImage: "target")
                        .font(.subheadline).padding(.horizontal, 20).frame(minHeight: 44)
                        .background(StreakStyle.orange, in: Capsule())
                }
                .buttonStyle(.plain).padding(.top, 80)
            }
            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity)
    }
}
