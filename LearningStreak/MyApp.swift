import SwiftUI

@main
struct MyApp: App {
    // @State يحتفظ بنسخة واحدة من ViewModel؛ كل الشاشات تتعامل مع نفس البيانات.
    @State private var viewModel = LearningGoalViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .tint(.orange)
        }
    }
}

struct RootView: View {
    @Bindable var viewModel: LearningGoalViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // وجود الهدف يحدد الشاشة؛ نجاح الحفظ يغيّر البيانات فتتغير الشاشة تلقائيًا.
        Group {
            if viewModel.loadFailed {
                ContentUnavailableView {
                    Label("Couldn't open your goal", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved file has been kept. Try opening it again.")
                } actions: {
                    Button("Try Again") { viewModel.load() }
                }
            } else if viewModel.currentGoal == nil {
                OnboardingView(viewModel: viewModel)
            } else {
                ActivityView(viewModel: viewModel)
            }
        }
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.calendar, viewModel.calendar)
        .environment(\.timeZone, viewModel.calendar.timeZone)
        .alert("Something needs attention", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshDate() }
        }
        .task(id: viewModel.calendar.timeZone.identifier) {
            // ننتظر منتصف الليل القادم ثم نحدّث التاريخ؛ الخروج من الشاشة يلغي الانتظار.
            while !Task.isCancelled {
                viewModel.refreshDate()
                let date = Date()
                let start = viewModel.calendar.startOfDay(for: date)
                let nextDay = viewModel.calendar.date(byAdding: .day, value: 1, to: start)!
                let seconds = max(1, nextDay.timeIntervalSince(date))
                do { try await Task.sleep(for: .seconds(seconds)) }
                catch { return }
            }
        }
    }
}
