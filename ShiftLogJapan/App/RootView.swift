import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var settings: [UserSettings]

    var body: some View {
        Group {
            if settings.first?.onboardingCompleted == true {
                MainTabView()
            } else {
                OnboardingView(existingSettings: settings.first)
            }
        }
        .tint(Color(hex: "315C8C"))
        .environment(\.locale, Locale(identifier: settings.first?.localeCode ?? Locale.current.identifier))
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingNewShift = false

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarDashboardView().tabItem { Label("tab.calendar", systemImage: "calendar") }.tag(0)
            EarningsView().tabItem { Label("tab.earnings", systemImage: "yensign.circle") }.tag(1)
            JobsView().tabItem { Label("tab.jobs", systemImage: "briefcase") }.tag(2)
            SettingsView().tabItem { Label("tab.me", systemImage: "person.crop.circle") }.tag(3)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { showingNewShift = true } label: {
                Image(systemName: "plus").font(.title2.bold()).frame(width: 56, height: 56)
                    .foregroundStyle(.white).background(Color.accentColor, in: Circle()).platformGlass().shadow(radius: 8, y: 4)
            }
            .accessibilityLabel("shift.add")
            .accessibilityIdentifier("shift.add")
            .padding(.trailing, 20).padding(.bottom, 64)
        }
        .sheet(isPresented: $showingNewShift) { ShiftEditorView() }
    }
}
