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
                .frame(minWidth: 520, minHeight: 680)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 860)
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
    enum Tab: Hashable { case home, browse, signs, assistant }

    @State private var tab: Tab = .home
    @State private var series: Series?
    @State private var topic: AssistantTopic?
    @State private var showTopic = false
    @Environment(AppModel.self) private var app

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView(start: { series = $0 }) }
                .tabItem { Label("Accueil", systemImage: "house.fill") }
                .tag(Tab.home)
            NavigationStack { BrowseView() }
                .tabItem { Label("Questions", systemImage: "magnifyingglass") }
                .tag(Tab.browse)
            NavigationStack { SignsView() }
                .tabItem { Label("Panneaux", systemImage: "exclamationmark.triangle") }
                .tag(Tab.signs)
            NavigationStack { AssistantView(topic: nil) }
                .tabItem { Label("Assistant", systemImage: "sparkles") }
                .tag(Tab.assistant)
        }
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

    private var topicSheet: some View {
        NavigationStack { AssistantView(topic: topic) }
            .dragIndicator()
    }
}
