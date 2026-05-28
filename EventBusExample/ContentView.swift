import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            EventBusDemoView()
                .tabItem { Label("Live Demo", systemImage: "play.circle.fill") }
            KafkaComparisonView()
                .tabItem { Label("vs Kafka", systemImage: "arrow.triangle.branch") }
        }
    }
}
