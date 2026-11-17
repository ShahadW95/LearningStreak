import SwiftUI

// شاشة البداية: مدخلات فقط؛ إنشاء الهدف والتحقق والحفظ مسؤولية ViewModel.
struct OnboardingView: View {
    @Bindable var viewModel: LearningGoalViewModel
    @FocusState private var titleFocused: Bool

    var body: some View {
        // GeometryReader يعطينا ارتفاع المساحة المتاحة؛ ScrollView يمنع القص مع الكيبورد والخط الكبير.
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(StreakStyle.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                        .padding(.bottom, 76)
                        .accessibilityHidden(true)

                    Text("Hello \(Text("Learner").bold())")
                        .font(.largeTitle)
                    Text("This app will help you learn everyday!")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.top, 4)

                    // الـ binding يربط الحقل بمسودة الاسم، وليس بهدف محفوظ مسبقًا.
                    GoalFields(title: $viewModel.goalTitle, duration: $viewModel.selectedDuration,
                               focused: $titleFocused)
                        .padding(.top, 40)

                    Spacer(minLength: 60)
                    Button {
                        titleFocused = false
                        viewModel.startLearning()
                    } label: {
                        Text("Start Learning").font(.subheadline.weight(.medium))
                            .padding(.horizontal, 24).frame(minHeight: 44)
                            .background(StreakStyle.orange.opacity(viewModel.canStartLearning ? 1 : 0.4), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canStartLearning)
                    .frame(maxWidth: .infinity)
                    Text("You can edit your desire later")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 12)
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
                .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(.black)
    }
}

// حقول مشتركة بين البداية والتعديل حتى يبقى ترتيبها وشكل اختيار المدة موحدًا.
struct GoalFields: View {
    @Binding var title: String
    @Binding var duration: GoalDuration
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("I want to learn").font(.subheadline)
            TextField("Swift", text: $title)
                .font(.body).textFieldStyle(.plain)
                .focused(focused).submitLabel(.done)
                .onSubmit { focused.wrappedValue = false }
                .padding(.top, 16).padding(.bottom, 12)
                .accessibilityLabel("Learning goal")
            Divider()
            Text("I want to learn it in a").font(.subheadline).padding(.top, 28)
            DurationPicker(selection: $duration).padding(.top, 12)
        }
    }
}

// أزرار كبسولية منفصلة مثل المرجع بدل segmented Picker؛ القيمة ما زالت enum واحدًا.
struct DurationPicker: View {
    @Binding var selection: GoalDuration

    var body: some View {
        HStack(spacing: 12) {
            ForEach(GoalDuration.allCases, id: \.self) { duration in
                let selected = selection == duration
                Button { selection = duration } label: {
                    Text(duration.rawValue).font(.subheadline)
                        .foregroundStyle(selected ? Color.white : Color.secondary)
                        .padding(.horizontal, 20).frame(minHeight: 44)
                        .background(selected ? StreakStyle.orange : Color(white: 0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(selected ? 0.5 : 0.2)))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}

// ألوان وثيم بسيط مشترك؛ لا يحتاج Assets ولا مكتبة خارجية.
enum StreakStyle {
    static let orange = Color(red: 1, green: 0.56, blue: 0.14)
    static let cyan = Color(red: 0.12, green: 0.77, blue: 0.91)
}

// رأس الصفحات الفرعية: رجوع دائري، عنوان في المنتصف، وتأكيد اختياري في شاشة التعديل.
struct StreakPageHeader: View {
    let title: String
    var save: (() -> Void)? = nil
    var saveEnabled = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    .background(Color(white: 0.1), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.25)))
            }
            .accessibilityLabel("Back")
            Spacer()
            Text(title).font(.headline)
            Spacer()
            if let save {
                Button(action: save) {
                    Image(systemName: "checkmark").font(.title3)
                        .frame(width: 44, height: 44)
                        .background(StreakStyle.orange.opacity(saveEnabled ? 1 : 0.4), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.45)))
                }
                .disabled(!saveEnabled).accessibilityLabel("Save goal")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.black)
    }
}
