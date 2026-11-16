
import SwiftUI

struct ActivityView: View {
    let viewModel: LearningGoalViewModel

    private let orange = Color(red: 1, green: 0.55, blue: 0.14)
    private let cyan = Color.cyan

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Activity")
                        .font(.largeTitle.bold())

                    Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                        .foregroundStyle(.gray)
                }

                Spacer()
            }

            if let goal = viewModel.currentGoal {
                Text("Learning: \(goal.title)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 14) {
                counterCard(
                    icon: "flame.fill",
                    count: viewModel.learnedCount,
                    title: "Learned",
                    color: orange
                )

                counterCard(
                    icon: "snowflake",
                    count: viewModel.freezeCount,
                    title: "Freezed",
                    color: cyan
                )
            }

            Spacer()

            Button {
                viewModel.logLearnedToday()
            } label: {
                Text(viewModel.hasLearnedToday
                     ? "Logged as Learned"
                     : "Log as Learned")
                    .fontWeight(.semibold)
                    .frame(width: 230, height: 230)
                    .background(
                        viewModel.hasLearnedToday
                        ? Color.white.opacity(0.12) : orange
                    )
                    .clipShape(Circle())
            }
            .disabled(viewModel.hasLearnedToday)

            Spacer()

            Button {
                viewModel.freezeToday()
            } label: {
                Text(viewModel.hasFrozenToday
                     ? "Freezed for a day"
                     : "Freeze for a day")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background(
                        viewModel.canFreezeToday
                        ? cyan : Color.white.opacity(0.12)
                    )
                    .clipShape(Capsule())
            }
            .disabled(!viewModel.canFreezeToday)

            Text("\(viewModel.freezeCount) out of \(viewModel.freezeLimit) Freezes used")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(.black)
    }

    private func counterCard(
        icon: String,
        count: Int,
        title: String,
        color: Color
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)

            Text("\(count) \(count == 1 ? "day" : "days")")
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.25))
        }
    }
}

