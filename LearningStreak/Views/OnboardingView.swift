
import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: LearningGoalViewModel

    private let orange = Color(red: 1, green: 0.55, blue: 0.14)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            Spacer()

            Image(systemName: "flame.fill")
                .font(.system(size: 48))
                .foregroundStyle(orange)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 65)

            VStack(alignment: .leading, spacing: 5) {
                Text("Hello Learner")
                    .font(.system(size: 34, weight: .bold))

                Text("This app will help you learn everyday!")
                    .foregroundStyle(.gray)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("I want to learn")

                TextField("Swift", text: $viewModel.goalTitle)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 10)

                Divider()

                Text("I want to learn it in a")
                    .padding(.top, 12)

                HStack(spacing: 12) {
                    ForEach(GoalDuration.allCases, id: \.self) { duration in
                        Button {
                            viewModel.selectedDuration = duration
                        } label: {
                            Text(duration.rawValue)
                                .padding(.horizontal, 19)
                                .padding(.vertical, 12)
                                .background(
                                    viewModel.selectedDuration == duration
                                    ? orange : Color.white.opacity(0.12)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            Button {
                viewModel.startLearning()
            } label: {
                Text("Start Learning")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(orange)
                    .clipShape(Capsule())
            }
            .disabled(!viewModel.canStartLearning)
            .opacity(viewModel.canStartLearning ? 1 : 0.4)
            .frame(maxWidth: .infinity)

            Text("You can edit your desire later")
                .font(.caption)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(.black)
    }
}

