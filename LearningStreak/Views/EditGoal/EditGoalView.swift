import SwiftUI

// صفحة كاملة مثل المرجع: مسودة محلية، رجوع يلغي، وعلامة الصح تطلب التأكيد قبل Update.
struct EditGoalView: View {
    let viewModel: LearningGoalViewModel
    var isNewCycle = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @State private var title: String
    @State private var duration: GoalDuration
    @State private var confirmingUpdate = false
    @AccessibilityFocusState private var confirmationFocused: Bool
    @ScaledMetric(relativeTo: .subheadline) private var confirmationButtonHeight: CGFloat = 44
    @State private var validationMessage: String?

    init(viewModel: LearningGoalViewModel, goal: LearningGoal, isNewCycle: Bool = false) {
        self.viewModel = viewModel
        self.isNewCycle = isNewCycle
        // دورة جديدة تبدأ بحقول البداية، ولا تورث اسم الهدف السابق أو مدته.
        _title = State(initialValue: isNewCycle ? "" : goal.title)
        _duration = State(initialValue: isNewCycle ? .week : goal.duration)
    }

    // نفس الاسم والمدة ليس تعديلًا أثناء الهدف، لكن يسمح بإعادة نفس الهدف بعد انتهاء مدته.
    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return isNewCycle || trimmed != viewModel.currentGoal?.title || duration != viewModel.currentGoal?.duration
    }

    var body: some View {
        VStack(spacing: 0) {
            StreakPageHeader(title: "Learning Goal", save: {
                titleFocused = false
                confirmingUpdate = true
            }, saveEnabled: canSave)
            ScrollView {
                GoalFields(title: $title, duration: $duration, focused: $titleFocused)
                    .padding(.horizontal, 16).padding(.top, 48)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(.black)
        .toolbar(.hidden, for: .navigationBar)
        // نوقف التفاعل بالخلفية أثناء التأكيد؛ إجراءات الحفظ تبقى نفسها.
        .allowsHitTesting(!confirmingUpdate)
        .accessibilityHidden(confirmingUpdate)
        .overlay {
            if confirmingUpdate { confirmationPopup }
        }
        .alert("Couldn't save goal", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { validationMessage = nil }
        } message: { Text(validationMessage ?? "") }
    }

    // نافذة مخصصة لمطابقة التصميم: Update برتقالي ممتلئ والنصوص بيضاء.
    private var confirmationPopup: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text(isNewCycle ? "Set a goal" : "Update goal")
                    .font(.headline).foregroundStyle(.white)
                    .accessibilityFocused($confirmationFocused)
                Text("If you update now, your streak will start over.")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button { confirmingUpdate = false } label: {
                        Text("Dismiss")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .frame(height: confirmationButtonHeight)
                            .streakGlass(in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    Button {
                        confirmingUpdate = false
                        if viewModel.updateGoal(title: title, duration: duration) {
                            dismiss()
                        } else {
                            validationMessage = viewModel.errorMessage
                            viewModel.errorMessage = nil
                        }
                    } label: {
                        Text(isNewCycle ? "Start" : "Update")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .frame(height: confirmationButtonHeight)
                            .streakGlass(in: Capsule(), tint: StreakStyle.orange)
                    }
                    // نفس تنسيق وحجم Dismiss؛ الاختلاف الوحيد لون المادة.
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(18).frame(maxWidth: 300)
            .streakGlass(in: RoundedRectangle(cornerRadius: 28), interactive: false)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .onAppear { confirmationFocused = true }
        }
    }
}
