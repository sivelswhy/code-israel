import CodeIsraelKit
import SwiftUI

@main
struct CodeIsraelApp: App {
    @State private var app = AppModel()
    @State private var engines = AIEngines()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(engines)
                #if os(macOS)
                .frame(minWidth: 820, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 780)
        #endif
    }
}

/// A series of questions being played.
struct Series: Identifiable {
    enum Mode { case exam, practice }

    let id = UUID()
    let mode: Mode
    let title: String
    let questions: [Question]
}

struct RootView: View {
    enum Tab: String, Hashable {
        case home, browse, signs, assistant
        init?(argument: String?) { self.init(rawValue: argument ?? "") }
    }

    /// `-initialTab browse` (or signs, assistant) on the command line opens that tab: handy to check each screen.
    @State private var tab: Tab = Tab(argument: UserDefaults.standard.string(forKey: "initialTab")) ?? .home
    @State private var series: Series?
    @State private var topic: AssistantTopic?
    @State private var showTopic = false
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    @ViewBuilder private var content: some View {
        if UserDefaults.standard.bool(forKey: "mascotGallery") { MascotGallery() } else { layout }
    }

    var body: some View {
        content
        .task { app.refreshJourney() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { app.refreshJourney() } }
        .environment(\.askAssistant) { topic in
            self.topic = topic
            showTopic = true
        }
        .fullScreenCoverCompat(item: $series) { s in
            QuizFlow(series: s, start: { series = $0 })
                .environment(\.askAssistant) { topic in
                    self.topic = topic
                    showTopic = true
                }
                .sheet(isPresented: $showTopic) { topicSheet }
        }
        .sheet(isPresented: Binding(get: { showTopic && series == nil }, set: { showTopic = $0 })) { topicSheet }
    }

    private var home: some View {
        NavigationStack {
            if app.mode == .journey { JourneyView() } else { HomeView(start: { series = $0 }) }
        }
    }

    private var homeLabel: (title: String, icon: String) {
        app.mode == .journey ? ("Parcours", "map.fill") : ("Accueil", "house.fill")
    }
    private var browse: some View { NavigationStack { BrowseView() } }
    private var signs: some View { NavigationStack { SignsView() } }
    private var assistant: some View { NavigationStack { AssistantView(topic: nil) } }

    @ViewBuilder private var layout: some View {
        #if os(macOS)
        // A sidebar, like a Mac app, and content kept to a readable width instead of stretched.
        NavigationSplitView {
            List(selection: Binding(get: { tab }, set: { if let t = $0 { tab = t } })) {
                Label(homeLabel.title, systemImage: homeLabel.icon).tag(Tab.home)
                Label("Questions", systemImage: "magnifyingglass").tag(Tab.browse)
                Label("Panneaux", systemImage: "exclamationmark.triangle").tag(Tab.signs)
                Label("Assistant", systemImage: "sparkles").tag(Tab.assistant)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            ZStack {
                Color.groupedBackground.ignoresSafeArea()
                Group {
                    switch tab {
                    case .home: home
                    case .browse: browse
                    case .signs: signs
                    case .assistant: assistant
                    }
                }
                .readableWidth(tab == .home || tab == .assistant ? 1180 : .infinity)
            }
        }
        #else
        TabView(selection: $tab) {
            home
                .tabItem { Label(homeLabel.title, systemImage: homeLabel.icon) }
                .tag(Tab.home)
            browse
                .tabItem { Label("Questions", systemImage: "magnifyingglass") }
                .tag(Tab.browse)
            signs
                .tabItem { Label("Panneaux", systemImage: "exclamationmark.triangle") }
                .tag(Tab.signs)
            assistant
                .tabItem { Label("Assistant", systemImage: "sparkles") }
                .tag(Tab.assistant)
        }
        #endif
    }

    private var topicSheet: some View {
        NavigationStack { AssistantView(topic: topic) }
            .dragIndicator()
            .sheetSize()
    }
}
