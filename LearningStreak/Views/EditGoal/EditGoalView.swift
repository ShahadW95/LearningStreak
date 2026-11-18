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
        // Alert نظامي واضح قبل بدء دورة جديدة. Cancel/الرجوع لا يستدعيان الحفظ.
        .alert(isNewCycle ? "Set a goal" : "Update goal", isPresented: $confirmingUpdate) {
            Button("Dismiss", role: .cancel) { }
            Button(isNewCycle ? "Start" : "Update") {
                if viewModel.updateGoal(title: title, duration: duration) {
                    dismiss()
                } else {
                    validationMessage = viewModel.errorMessage
                    viewModel.errorMessage = nil
                }
            }
        } message: {
            Text("If you update now, your streak will start over. Previous activity stays in your calendar.")
        }
        .alert("Couldn't save goal", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { validationMessage = nil }
        } message: { Text(validationMessage ?? "") }
    }
}
