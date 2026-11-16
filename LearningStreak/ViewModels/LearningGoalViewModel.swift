
import Foundation
import Observation

@Observable
final class LearningGoalViewModel {
    var goalTitle = ""
    var selectedDuration: GoalDuration = .week

    private(set) var currentGoal: LearningGoal?
    private(set) var learnedDates: Set<Date> = []
    private(set) var frozenDates: Set<Date> = []

    var canStartLearning: Bool {
        !goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var learnedCount: Int {
        learnedDates.count
    }

    var freezeCount: Int {
        frozenDates.count
    }

    var freezeLimit: Int {
        switch currentGoal?.duration ?? selectedDuration {
        case .week: 2
        case .month: 8
        case .year: 96
        }
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var hasLearnedToday: Bool {
        learnedDates.contains(today)
    }

    var hasFrozenToday: Bool {
        frozenDates.contains(today)
    }

    var canFreezeToday: Bool {
        !hasFrozenToday && !hasLearnedToday && freezeCount < freezeLimit
    }

    func startLearning() {
        guard canStartLearning else { return }

        currentGoal = LearningGoal(
            title: goalTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: selectedDuration
        )

        learnedDates.removeAll()
        frozenDates.removeAll()
    }

    func logLearnedToday() {
        guard currentGoal != nil, !hasLearnedToday else { return }
        learnedDates.insert(today)
    }

    func freezeToday() {
        guard currentGoal != nil, canFreezeToday else { return }
        frozenDates.insert(today)
    }
}


