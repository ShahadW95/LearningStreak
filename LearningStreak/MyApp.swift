
import SwiftUI

@main
struct MyApp: App {
    @State private var viewModel = LearningGoalViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.currentGoal == nil {
                    OnboardingView(viewModel: viewModel)
                } else {
                    ActivityView(viewModel: viewModel)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
