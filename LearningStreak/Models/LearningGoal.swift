
import Foundation

struct LearningGoal: Identifiable, Codable {
    let id: UUID
    var title: String
    var duration: GoalDuration
    let startDate: Date

    init(title: String, duration: GoalDuration) {
        self.id = UUID()
        self.title = title
        self.duration = duration
        self.startDate = Date()
    }
}


