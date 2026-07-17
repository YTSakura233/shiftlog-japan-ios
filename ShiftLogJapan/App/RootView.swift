import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var settings: [UserSettings]
    @State private var showingLaunchSplash = ProcessInfo.processInfo.environment["UITEST_DISABLE_SPLASH"] != "1"

    var body: some View {
        ZStack {
            Group {
                if settings.first?.onboardingCompleted == true {
                    MainTabView()
                } else {
                    OnboardingView(existingSettings: settings.first)
                }
            }

            if showingLaunchSplash {
                LaunchSplashView()
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.03)))
                    .zIndex(10)
            }
        }
        .tint(Color(hex: "315C8C"))
        .environment(\.locale, Locale(identifier: settings.first?.localeCode ?? Locale.current.identifier))
        .task {
            guard showingLaunchSplash else { return }
            try? await Task.sleep(for: reduceMotion ? .milliseconds(450) : .milliseconds(1_500))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.38)) {
                showingLaunchSplash = false
            }
        }
    }
}

struct MainTabView: View {
    @Query private var settings: [UserSettings]
    @Query private var jobs: [Job]
    @Query private var shifts: [Shift]
    @Query private var breaks: [ShiftBreak]
    @State private var selectedTab = 0
    @State private var showingNewShift = false

    private var widgetSnapshotVersion: Int {
        var hasher = Hasher()
        settings.forEach { hasher.combine($0.localeCode); hasher.combine($0.updatedAt) }
        jobs.forEach { hasher.combine($0.id); hasher.combine($0.displayName); hasher.combine($0.colorHex); hasher.combine($0.updatedAt) }
        shifts.forEach { hasher.combine($0.id); hasher.combine($0.updatedAt); hasher.combine($0.isDeleted) }
        breaks.forEach { hasher.combine($0.id); hasher.combine($0.start); hasher.combine($0.end) }
        return hasher.finalize()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarDashboardView().tabItem { Label("tab.calendar", systemImage: "calendar") }.tag(0)
            EarningsView().tabItem { Label("tab.earnings", systemImage: "yensign.circle") }.tag(1)
            JobsView().tabItem { Label("tab.jobs", systemImage: "briefcase") }.tag(2)
            SettingsView().tabItem { Label("tab.me", systemImage: "person.crop.circle") }.tag(3)
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab == 0 {
                Button { showingNewShift = true } label: {
                    Image(systemName: "plus").font(.title2.bold()).frame(width: 56, height: 56)
                        .foregroundStyle(.white).background(Color.accentColor, in: Circle()).platformGlass().shadow(radius: 8, y: 4)
                }
                .accessibilityLabel("shift.add")
                .accessibilityIdentifier("shift.add")
                .padding(.trailing, 20).padding(.bottom, 64)
            }
        }
        .sheet(isPresented: $showingNewShift) { ShiftEditorView() }
        .task(id: widgetSnapshotVersion) {
            WidgetSnapshotService.update(
                jobs: jobs,
                shifts: shifts,
                breaks: breaks,
                localeCode: settings.first?.localeCode ?? AppLanguage.preferred().rawValue
            )
        }
    }
}
