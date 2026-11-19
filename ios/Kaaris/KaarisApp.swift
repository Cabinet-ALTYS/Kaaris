import AVFoundation
import SwiftUI
import UserNotifications

let ink = Color(red: 16/255, green: 16/255, blue: 18/255)
let panel = Color(red: 25/255, green: 25/255, blue: 29/255)
let lineColor = Color(red: 48/255, green: 48/255, blue: 54/255)
let acid = Color(red: 232/255, green: 1, blue: 66/255)
let muted = Color(red: 166/255, green: 166/255, blue: 174/255)

@main
struct KaarisApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notifications
    @StateObject private var store = CoachStore()
    @StateObject private var connection = KaarisConnection()

    var body: some Scene {
        WindowGroup {
            KaarisRoot()
                .environmentObject(store)
                .environmentObject(connection)
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .preferredColorScheme(.dark)
                .tint(acid)
                .task { connection.restoreAccount() }
                .onChange(of: connection.isSignedIn) { wasSignedIn, isSignedIn in
                    if wasSignedIn && !isSignedIn { store.preferences.onlineCoachConsent = nil }
                }
        }
    }
}

final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .openCoachCheckin, object: nil)
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

extension Notification.Name {
    static let openCoachCheckin = Notification.Name("openCoachCheckin")
}

enum KaarisTab: String, CaseIterable {
    case home = "Aujourd’hui"
    case plan = "Plan"
    case coach = "Coach"
    case settings = "Réglages"

    var icon: String {
        switch self {
        case .home: "bolt.fill"
        case .plan: "calendar"
        case .coach: "waveform"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct KaarisRoot: View {
    @EnvironmentObject private var store: CoachStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = KaarisTab.home

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()
            if store.hasOnboarded {
                NavigationStack {
                    Group {
                        switch selection {
                        case .home: TodayScreen(selection: $selection)
                        case .plan: PlanScreen()
                        case .coach: CoachScreen()
                        case .settings: SettingsScreen()
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        HStack(spacing: 2) {
                            ForEach(KaarisTab.allCases, id: \.self) { tab in
                                Button {
                                    selection = tab
                                } label: {
                                    VStack(spacing: 5) {
                                        Image(systemName: tab.icon).font(.system(size: 19, weight: .semibold))
                                        Text(tab.rawValue).font(.caption2.weight(.semibold))
                                    }
                                    .foregroundStyle(selection == tab ? acid : muted)
                                    .frame(maxWidth: .infinity, minHeight: 57)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(ink.ignoresSafeArea(edges: .bottom))
                        .overlay(alignment: .top) { Rectangle().fill(lineColor).frame(height: 1) }
                    }
                }
            } else {
                OnboardingScreen()
            }
        }
        .onAppear {
            guard ProcessInfo.processInfo.arguments.contains("--demo") else { return }
            for option in KaarisTab.allCases where ProcessInfo.processInfo.arguments.contains("--tab-\(option)") {
                selection = option
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCoachCheckin)) { _ in
            selection = .coach
        }
        .onOpenURL { url in
            if url.scheme == "kaaris", url.host == "checkin" { selection = .coach }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.hasOnboarded { store.refreshReminders() }
        }
    }
}

struct KPage<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) { content }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(ink)
    }
}

struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased()).font(.system(.caption, design: .monospaced).weight(.semibold))
            .tracking(1.7)
            .foregroundStyle(acid)
    }
}

struct KTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 45, weight: .black).width(.condensed))
            .tracking(-1.8)
            .accessibilityAddTraits(.isHeader)
    }
}

struct BrandMark: View {
    var body: some View {
        HStack(spacing: 7) {
            Image("Logo").resizable().frame(width: 35, height: 35)
                .accessibilityHidden(true)
            Text("KAARIS")
                .font(.system(size: 25, weight: .black).width(.condensed))
                .tracking(1.7)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ActionStyle: ButtonStyle {
    var filled = true
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .default).weight(.heavy))
            .foregroundStyle(filled ? ink : .white)
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(filled ? acid : panel, in: RoundedRectangle(cornerRadius: 13))
            .overlay { if !filled { RoundedRectangle(cornerRadius: 13).strokeBorder(lineColor) } }
            .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
            .contentShape(Rectangle())
    }
}

extension View {
    func kPanel() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(panel, in: RoundedRectangle(cornerRadius: 19))
            .overlay { RoundedRectangle(cornerRadius: 19).strokeBorder(lineColor) }
    }
}

func dateLabel(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
}

func hourLabel(_ date: Date) -> String {
    date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "fr_FR")))
}

struct CoachPortrait: View {
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Image("Coach")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width)
                .frame(height: geometry.size.height, alignment: .top)
                .clipped()
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
