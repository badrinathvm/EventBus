import SwiftUI

// MARK: - Main View

struct KafkaComparisonView: View {
    @State private var isAnimating = false

    // EventBus node states
    @State private var ebPublisher = false
    @State private var ebBus = false
    @State private var ebInbox = false
    @State private var ebPresence = false
    @State private var ebTyping = false

    // Kafka node states
    @State private var kProducer = false
    @State private var kBroker = false
    @State private var kLogCount = 0
    @State private var kInbox = false
    @State private var kPresence = false
    @State private var kTyping = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    architectureSection
                    comparisonSection
                    whenToUseSection
                }
                .padding()
            }
            .navigationTitle("EventBus vs Kafka")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Architecture

    private var architectureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Architecture")
                        .font(.title3.bold())
                    Text("Tap \"Fire Event\" to see how each system delivers a message.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Fire Event") {
                    guard !isAnimating else { return }
                    isAnimating = true
                    Task { @MainActor in
                        await runAnimation()
                        isAnimating = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAnimating)
            }

            HStack(alignment: .top, spacing: 12) {
                EventBusFlowCard(
                    publisherActive: ebPublisher,
                    busActive: ebBus,
                    inboxActive: ebInbox,
                    presenceActive: ebPresence,
                    typingActive: ebTyping
                )
                KafkaFlowCard(
                    producerActive: kProducer,
                    brokerActive: kBroker,
                    logCount: kLogCount,
                    inboxActive: kInbox,
                    presenceActive: kPresence,
                    typingActive: kTyping
                )
            }
        }
    }

    private func runAnimation() async {
        // EventBus: fast, synchronous, in-process (~800 ms total)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { ebPublisher = true }
        try? await Task.sleep(for: .milliseconds(280))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { ebBus = true }
        try? await Task.sleep(for: .milliseconds(280))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            ebInbox = true; ebPresence = true; ebTyping = true
        }

        // Kafka: async, broker-mediated, persisted (~2 s total, starts 50 ms after EventBus)
        try? await Task.sleep(for: .milliseconds(50))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { kProducer = true }
        try? await Task.sleep(for: .milliseconds(500))   // network trip to broker
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { kBroker = true }
        try? await Task.sleep(for: .milliseconds(300))   // write to durable log
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { kLogCount += 1 }
        try? await Task.sleep(for: .milliseconds(600))   // consumers poll / receive
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            kInbox = true; kPresence = true; kTyping = true
        }

        // Reset active states — log count stays to show persistence
        try? await Task.sleep(for: .milliseconds(1200))
        withAnimation(.easeOut(duration: 0.5)) {
            ebPublisher = false; ebBus = false
            ebInbox = false; ebPresence = false; ebTyping = false
            kProducer = false; kBroker = false
            kInbox = false; kPresence = false; kTyping = false
        }
    }

    // MARK: Comparison table

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Comparison")
                .font(.title3.bold())

            VStack(spacing: 0) {
                ComparisonHeader()
                ForEach(Array(ComparisonRowData.allRows.enumerated()), id: \.offset) { index, row in
                    ComparisonRowView(row: row, isEven: index % 2 == 0)
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
    }

    // MARK: When to use

    private var whenToUseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When to Use Each")
                .font(.title3.bold())

            HStack(alignment: .top, spacing: 12) {
                WhenToUseCard(
                    title: "Use EventBus",
                    tint: .blue,
                    icon: "iphone",
                    points: [
                        "UI event coordination within an app",
                        "Zero infrastructure, zero latency",
                        "Automatic cleanup via weak ownership",
                        "Single-process component decoupling",
                    ]
                )
                WhenToUseCard(
                    title: "Use Kafka",
                    tint: .orange,
                    icon: "server.rack",
                    points: [
                        "Cross-service messaging at scale",
                        "Event replay and audit logging",
                        "Independent consumer groups",
                        "Durability across service restarts",
                    ]
                )
            }
        }
    }
}

// MARK: - Flow Cards

private struct EventBusFlowCard: View {
    let publisherActive: Bool
    let busActive: Bool
    let inboxActive: Bool
    let presenceActive: Bool
    let typingActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            cardHeader("EventBus", color: .blue)

            PulsingNode("iphone", "Publisher", .blue, publisherActive)
            VerticalConnector(.blue)
            PulsingNode("bolt.fill", "EventBus", .indigo, busActive)
            FanOutConnector(colors: [.blue, .green, .purple])

            HStack(spacing: 0) {
                PulsingNode("envelope.fill", "Inbox", .blue, inboxActive).frame(maxWidth: .infinity)
                PulsingNode("person.2.fill", "Presence", .green, presenceActive).frame(maxWidth: .infinity)
                PulsingNode("ellipsis.bubble.fill", "Typing", .purple, typingActive).frame(maxWidth: .infinity)
            }

            Spacer(minLength: 12)
            callouts([
                "⚡️ Direct, synchronous delivery",
                "🧠 In-process — no broker",
                "♻️ Auto-cleanup via weak refs",
            ])
        }
        .padding(12)
        .background(.blue.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct KafkaFlowCard: View {
    let producerActive: Bool
    let brokerActive: Bool
    let logCount: Int
    let inboxActive: Bool
    let presenceActive: Bool
    let typingActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            cardHeader("Kafka", color: .orange)

            PulsingNode("iphone", "Producer", .orange, producerActive)
            VerticalConnector(.orange)

            // Broker + durable log group
            VStack(spacing: 6) {
                PulsingNode("server.rack", "Broker", .orange, brokerActive)
                KafkaLogStrip(count: logCount)
                Text("durable log · offset-based")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.orange.opacity(0.7))
            }
            .padding(8)
            .background(.orange.opacity(0.08))
            .clipShape(.rect(cornerRadius: 8))

            FanOutConnector(colors: [.blue, .green, .purple])

            // Consumer groups with offset badges
            HStack(spacing: 0) {
                consumerColumn("envelope.fill", "Group A", .blue, inboxActive, logCount)
                consumerColumn("person.2.fill", "Group B", .green, presenceActive, logCount)
                consumerColumn("ellipsis.bubble.fill", "Group C", .purple, typingActive, logCount)
            }

            Spacer(minLength: 12)
            callouts([
                "🌐 Distributed, asynchronous",
                "💾 Persistent — survives restarts",
                "👥 Independent consumer groups",
            ])
        }
        .padding(12)
        .background(.orange.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.orange.opacity(0.2), lineWidth: 1)
        }
    }

    private func consumerColumn(
        _ icon: String, _ label: String, _ color: Color, _ active: Bool, _ offset: Int
    ) -> some View {
        VStack(spacing: 2) {
            PulsingNode(icon, label, color, active)
            Text("offset: \(offset)")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Shared helpers for card header and callouts
private func cardHeader(_ title: String, color: Color) -> some View {
    HStack(spacing: 5) {
        Circle().fill(color).frame(width: 8, height: 8)
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(color)
    }
    .padding(.bottom, 10)
}

private func callouts(_ lines: [String]) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        ForEach(lines, id: \.self) { line in
            Text(line)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

// MARK: - Shared Node & Connector Views

private struct PulsingNode: View {
    let systemImage: String
    let label: String
    let color: Color
    let isActive: Bool

    init(_ systemImage: String, _ label: String, _ color: Color, _ isActive: Bool) {
        self.systemImage = systemImage
        self.label = label
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(isActive ? 0.25 : 0.1))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isActive ? 1.12 : 1.0)
                    .shadow(color: color.opacity(isActive ? 0.45 : 0), radius: isActive ? 8 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)

                Image(systemName: systemImage)
                    .font(.body.bold())
                    .foregroundStyle(color)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isActive)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isActive ? color : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }
}

private struct VerticalConnector: View {
    let color: Color
    init(_ color: Color) { self.color = color }

    var body: some View {
        VStack(spacing: 1) {
            Rectangle()
                .fill(color.opacity(0.35))
                .frame(width: 1.5, height: 16)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 6))
                .foregroundStyle(color.opacity(0.35))
        }
    }
}

private struct FanOutConnector: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 1.5)
                .padding(.horizontal, 22)

            HStack(spacing: 0) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(width: 1.5, height: 14)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 14)
    }
}

private struct KafkaLogStrip: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            if count == 0 {
                Text("empty")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange.opacity(0.4))
                    .frame(height: 22)
            } else {
                ForEach(0..<count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange.opacity(max(0.85 - Double(i) * 0.12, 0.3)))
                        .frame(width: 20, height: 22)
                        .overlay(
                            Text("m\(i + 1)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: count)
    }
}

// MARK: - Comparison Table

private struct ComparisonRowData {
    let feature: String
    let eventBus: String
    let kafka: String
    enum Advantage { case eventBus, kafka, neutral }
    let advantage: Advantage

    static let allRows: [ComparisonRowData] = [
        .init(feature: "Scope",            eventBus: "In-process",    kafka: "Distributed",       advantage: .neutral),
        .init(feature: "Broker",           eventBus: "❌  None",       kafka: "✅  Required",       advantage: .neutral),
        .init(feature: "Persistence",      eventBus: "❌  Ephemeral",  kafka: "✅  Durable log",    advantage: .kafka),
        .init(feature: "Delivery",         eventBus: "Synchronous",   kafka: "Asynchronous",      advantage: .neutral),
        .init(feature: "Event replay",     eventBus: "❌",             kafka: "✅  Any offset",     advantage: .kafka),
        .init(feature: "Consumer groups",  eventBus: "❌",             kafka: "✅  Independent",    advantage: .kafka),
        .init(feature: "Ordering",         eventBus: "Call order",    kafka: "Per partition",     advantage: .neutral),
        .init(feature: "Latency",          eventBus: "✅  ~μs",        kafka: "~ms",               advantage: .eventBus),
        .init(feature: "Setup",            eventBus: "✅  Zero-config",kafka: "Infrastructure",    advantage: .eventBus),
        .init(feature: "Memory safety",    eventBus: "✅  Weak refs",  kafka: "N/A",               advantage: .eventBus),
    ]
}

private struct ComparisonHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Feature")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)

            Text("EventBus")
                .font(.caption.bold())
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)

            Text("Kafka")
                .font(.caption.bold())
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
    }
}

private struct ComparisonRowView: View {
    let row: ComparisonRowData
    let isEven: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(row.feature)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)

            Text(row.eventBus)
                .font(.caption)
                .fontWeight(row.advantage == .eventBus ? .semibold : .regular)
                .foregroundStyle(row.advantage == .eventBus ? Color.blue : Color.primary)
                .frame(maxWidth: .infinity)

            Text(row.kafka)
                .font(.caption)
                .fontWeight(row.advantage == .kafka ? .semibold : .regular)
                .foregroundStyle(row.advantage == .kafka ? Color.orange : Color.primary)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 7)
        .background(isEven ? Color.clear : Color.secondary.opacity(0.04))
    }
}

// MARK: - When to Use Card

private struct WhenToUseCard: View {
    let title: String
    let tint: Color
    let icon: String
    let points: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(tint)
                        Text(point)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        }
    }
}

#Preview {
    KafkaComparisonView()
}
