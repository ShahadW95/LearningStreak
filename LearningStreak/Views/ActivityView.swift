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
                            if viewModel.recoveryDay != nil { recoveryNotice.padding(.top, 20) }
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
                    NavigationLink { EditGoalView(viewModel: viewModel, goal: goal, isNewCycle: viewModel.isGoalFinished) } label: {
                        headerIcon("pencil.and.outline")
                    }.accessibilityLabel("Change learning goal")
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func headerIcon(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.title3).foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .streakGlass(in: Circle())
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
        // البطاقة ليست زرًا؛ نستخدم المادة الزجاجية بدون استجابة للمس.
        .streakGlass(in: RoundedRectangle(cornerRadius: 28), interactive: false)
        .accessibilityElement(children: .combine)
    }

    // لون رمادي يعني Learned مختار؛ يظل الزر فعالًا لإلغاء التسجيل عند الضغط مرة ثانية.
    private func learnedButton(diameter: CGFloat) -> some View {
        Button { viewModel.toggleLearned() } label: {
            Text(viewModel.hasLearnedActivityDay ? "Logged as Learned" : "Log as Learned")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(viewModel.hasLearnedActivityDay ? Color.secondary : Color.white)
                .multilineTextAlignment(.center).padding(24)
                .frame(width: diameter, height: diameter)
                .streakGlass(in: Circle(), tint: viewModel.hasLearnedActivityDay ? nil : StreakStyle.orange)
        }
        .buttonStyle(.plain).disabled(!viewModel.canLogSelectedDay)
        .accessibilityHint(viewModel.hasLearnedActivityDay ? "Tap again to undo learning for the displayed day" : "Records learning for the displayed day")
        .accessibilityAddTraits(viewModel.hasLearnedActivityDay ? [.isSelected] : [])
    }

    // حالات الزر: متاح، جُمّد اليوم، الرصيد انتهى، أو تم التعلّم. المنع موجود بالـ ViewModel أيضًا.
    private var freezeControls: some View {
        VStack(spacing: 14) {
            Button { viewModel.toggleFrozen() } label: {
                Text(viewModel.hasFrozenActivityDay ? "Frozen for a day" : "Freeze for a day")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(viewModel.canFreezeSelectedDay && !viewModel.hasFrozenActivityDay ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .streakGlass(in: Capsule(), tint: viewModel.canFreezeSelectedDay && !viewModel.hasFrozenActivityDay ? StreakStyle.cyan : nil)
            }
            .buttonStyle(.plain).disabled(!viewModel.canFreezeSelectedDay)
            .accessibilityHint(viewModel.hasFrozenActivityDay ? "Tap again to undo freeze for the displayed day" : "Replaces learning for the displayed day with a freeze if available")
            .accessibilityAddTraits(viewModel.hasFrozenActivityDay ? [.isSelected] : [])
            Text("\(viewModel.freezeCount) out of \(viewModel.freezeLimit) Freezes used")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 36)
    }

    // يظهر فقط وقت تعويض أمس؛ لا نخفي عن المستخدم أن الضغط يسجل لليوم الفائت.
    private var recoveryNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let day = viewModel.recoveryDay {
                Label(viewModel.hasRecordedRecoveryDay ? "Yesterday is recorded" : "8-hour grace period", systemImage: "clock")
                    .font(.headline)
                Text("These buttons update \(day, format: .dateTime.month(.abbreviated).day()), not today.")
                    .font(.subheadline)
                if viewModel.hasRecordedRecoveryDay {
                    Text("Tap the selected button to undo, switch your choice, or continue to today.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Continue to Today") { viewModel.continueToToday() }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(StreakStyle.orange)
                        .buttonStyle(.plain).frame(minHeight: 44)
                } else {
                    Text("Log or freeze before \(viewModel.deadline(for: day), format: .dateTime.hour().minute()) to keep your streak.")
                        .font(.caption)
                    Text(viewModel.deadline(for: day), style: .timer)
                        .font(.subheadline.monospacedDigit()).foregroundStyle(StreakStyle.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Color(white: 0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(StreakStyle.orange.opacity(0.35)))
    }

    // نهاية الفترة لها حالتان مثل المرجع؛ Set a goal يسمح باختيار نفس الهدف أو تغييره.
    private var resultContent: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.didMeetGoal ? "hands.clap.fill" : "xmark.seal")
                .font(.system(size: 44)).foregroundStyle(StreakStyle.orange)
                .padding(.bottom, 16)
            Text(viewModel.didMeetGoal ? "Well done!" : "You didn't reach your goal this time.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(viewModel.didMeetGoal ? "Ready for your next goal?" : "Want to set another goal?")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            if let goal = viewModel.currentGoal {
                NavigationLink {
                    EditGoalView(viewModel: viewModel, goal: goal, isNewCycle: true)
                } label: {
                    Label("Set a goal", systemImage: "pencil.and.outline")
                        .font(.subheadline).padding(.horizontal, 20).frame(minHeight: 44)
                        .foregroundStyle(.white)
                        .streakGlass(in: Capsule(), tint: StreakStyle.orange)
                }
                .buttonStyle(.plain).padding(.top, 80)
            }
            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity)
    }
}
