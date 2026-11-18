import SwiftUI
import UIKit

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
        // النظام ينبهنا عند تغيّر الساعة/اليوم؛ العودة من الخلفية تُفحص بالأعلى أيضًا.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            viewModel.refreshDate()
        }
        .task(id: viewModel.nextRefreshDate) {
            // مهمة واحدة تستيقظ عند الحد التالي (منتصف الليل أو الثامنة).
            // تغيّر الحد يلغي المهمة السابقة ويجدول الجديدة؛ لا نحتاج مؤقتًا يعمل كل ثانية.
            let seconds = max(0, viewModel.nextRefreshDate.timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(seconds)) }
            catch { return }
            viewModel.refreshDate()
        }
    }
}
