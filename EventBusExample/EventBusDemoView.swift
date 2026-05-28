import SwiftUI

// MARK: - Event Types

struct MessageReceivedEvent: EventBusEvent {
    let sender: String
    let text: String
}

struct UserStatusChangedEvent: EventBusEvent {
    let username: String
    let isOnline: Bool
}

struct TypingIndicatorEvent: EventBusEvent {
    let username: String
    let isTyping: Bool
}

// MARK: - Supporting Models

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let text: String
}

struct EventLogEntry: Identifiable {
    let id = UUID()
    let time = Date()
    let text: String
    let color: Color
}

// MARK: - View Model

// Handlers are always invoked on the main thread because publish() is called
// from SwiftUI button actions. For production use with arbitrary publishers,
// dispatch mutations via DispatchQueue.main.async before modifying state.
@Observable
final class EventBusDemoViewModel {
    var messages: [ChatMessage] = []
    var presenceMap: [String: Bool] = [:]
    var typingUsers: Set<String> = []
    var eventLog: [EventLogEntry] = []

    var isInboxSubscribed = true
    var isPresenceSubscribed = true
    var isTypingSubscribed = true

    var activeSubscriptionCount: Int {
        [isInboxSubscribed, isPresenceSubscribed, isTypingSubscribed].filter { $0 }.count
    }

    @ObservationIgnored private var inboxToken: EventBus.SubscriptionToken?
    @ObservationIgnored private var presenceToken: EventBus.SubscriptionToken?
    @ObservationIgnored private var typingToken: EventBus.SubscriptionToken?
    @ObservationIgnored private let bus: EventBus

    init(bus: EventBus = .shared) {
        self.bus = bus
        subscribeInbox()
        subscribePresence()
        subscribeTyping()
    }

    // MARK: Subscribe

    private func subscribeInbox() {
        inboxToken = bus.subscribe(owner: self, eventType: MessageReceivedEvent.self) { owner, event in
            owner.messages.insert(ChatMessage(sender: event.sender, text: event.text), at: 0)
            if owner.messages.count > 6 { owner.messages.removeLast() }
            owner.log("📬 \(event.sender): \"\(event.text)\"", color: .blue)
        }
    }

    private func subscribePresence() {
        presenceToken = bus.subscribe(owner: self, eventType: UserStatusChangedEvent.self) { owner, event in
            owner.presenceMap[event.username] = event.isOnline
            let status = event.isOnline ? "came online" : "went offline"
            owner.log("👤 \(event.username) \(status)", color: .green)
        }
    }

    private func subscribeTyping() {
        typingToken = bus.subscribe(owner: self, eventType: TypingIndicatorEvent.self) { owner, event in
            if event.isTyping {
                owner.typingUsers.insert(event.username)
            } else {
                owner.typingUsers.remove(event.username)
            }
            let action = event.isTyping ? "started typing" : "stopped typing"
            owner.log("⌨️ \(event.username) \(action)", color: .purple)
        }
    }

    // MARK: Toggle individual subscriptions

    func toggleInbox() {
        if isInboxSubscribed {
            inboxToken?.cancel()
            inboxToken = nil
            log("🔕 Inbox unsubscribed", color: .secondary)
        } else {
            subscribeInbox()
            log("🔔 Inbox subscribed", color: .secondary)
        }
        isInboxSubscribed.toggle()
    }

    func togglePresence() {
        if isPresenceSubscribed {
            presenceToken?.cancel()
            presenceToken = nil
            log("🔕 Presence unsubscribed", color: .secondary)
        } else {
            subscribePresence()
            log("🔔 Presence subscribed", color: .secondary)
        }
        isPresenceSubscribed.toggle()
    }

    func toggleTyping() {
        if isTypingSubscribed {
            typingToken?.cancel()
            typingToken = nil
            log("🔕 Typing unsubscribed", color: .secondary)
        } else {
            subscribeTyping()
            log("🔔 Typing subscribed", color: .secondary)
        }
        isTypingSubscribed.toggle()
    }

    // MARK: Bulk subscription management

    // Demonstrates unsubscribeAll(for:): cancels every subscription this owner
    // holds in a single call — no tokens required.
    func unsubscribeAll() {
        bus.unsubscribeAll(for: self)
        // Release stale tokens; their underlying cancellationState is already marked cancelled.
        inboxToken = nil
        presenceToken = nil
        typingToken = nil
        isInboxSubscribed = false
        isPresenceSubscribed = false
        isTypingSubscribed = false
        log("🚫 unsubscribeAll(for:) — all \u{200B}3 subscriptions cancelled at once", color: .red)
    }

    func subscribeAll() {
        if !isInboxSubscribed { subscribeInbox(); isInboxSubscribed = true }
        if !isPresenceSubscribed { subscribePresence(); isPresenceSubscribed = true }
        if !isTypingSubscribed { subscribeTyping(); isTypingSubscribed = true }
        log("🔔 Re-subscribed to all events", color: .secondary)
    }

    // MARK: Publish (simulated events)

    func publishMessage() {
        let senders = ["Alice", "Bob", "Charlie", "Diana"]
        let texts = ["Hey there!", "What's up?", "Got a minute?", "Meeting at 3?", "Check this out!"]
        bus.publish(MessageReceivedEvent(
            sender: senders.randomElement()!,
            text: texts.randomElement()!
        ))
    }

    func publishStatusChange() {
        let users = ["Alice", "Bob", "Charlie"]
        let user = users.randomElement()!
        bus.publish(UserStatusChangedEvent(username: user, isOnline: !(presenceMap[user] ?? false)))
    }

    func publishTyping() {
        let users = ["Alice", "Bob", "Charlie"]
        let user = users.randomElement()!
        bus.publish(TypingIndicatorEvent(username: user, isTyping: !typingUsers.contains(user)))
    }

    func clearLog() {
        eventLog.removeAll()
    }

    // MARK: Private

    private func log(_ text: String, color: Color) {
        eventLog.insert(EventLogEntry(text: text, color: color), at: 0)
        if eventLog.count > 20 { eventLog.removeLast() }
    }
}

// MARK: - Main Demo View

struct EventBusDemoView: View {
    @State private var model = EventBusDemoViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    publisherSection
                    subscribersSection
                    eventLogSection
                }
                .padding()
            }
            .navigationTitle("EventBus Demo")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Publisher

    private var publisherSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Publisher", systemImage: "dot.radiowaves.left.and.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    EventButton("Message", icon: "envelope.fill", tint: .blue) {
                        model.publishMessage()
                    }
                    EventButton("Status", icon: "person.fill.checkmark", tint: .green) {
                        model.publishStatusChange()
                    }
                    EventButton("Typing", icon: "ellipsis.bubble.fill", tint: .purple) {
                        model.publishTyping()
                    }
                }
            }
        }
    }

    // MARK: Subscribers

    private var subscribersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            subscribersHeader
            subscriberCards
            bulkControls
        }
    }

    private var subscribersHeader: some View {
        HStack(spacing: 6) {
            Text("Subscribers")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Spacer()

            // Live active-subscription counter
            let count = model.activeSubscriptionCount
            HStack(spacing: 3) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i < count ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: count)

            Text("\(count)/3 active")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(count > 0 ? .secondary : Color.red)
                .animation(.easeInOut(duration: 0.25), value: count)
        }
        .padding(.horizontal, 4)
    }

    private var subscriberCards: some View {
        HStack(alignment: .top, spacing: 12) {
            SubscriberCard(
                title: "Inbox",
                icon: "envelope.fill",
                tint: .blue,
                isSubscribed: model.isInboxSubscribed,
                onToggle: model.toggleInbox
            ) {
                if model.messages.isEmpty {
                    Text("No messages yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(model.messages) { msg in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg.sender)
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                            Text(msg.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            SubscriberCard(
                title: "Presence",
                icon: "person.2.fill",
                tint: .green,
                isSubscribed: model.isPresenceSubscribed,
                onToggle: model.togglePresence
            ) {
                if model.presenceMap.isEmpty {
                    Text("No status updates")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(model.presenceMap.keys.sorted(), id: \.self) { user in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(model.presenceMap[user] == true ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(user)
                                .font(.caption)
                        }
                    }
                }
            }

            SubscriberCard(
                title: "Typing",
                icon: "ellipsis.bubble.fill",
                tint: .purple,
                isSubscribed: model.isTypingSubscribed,
                onToggle: model.toggleTyping
            ) {
                if model.typingUsers.isEmpty {
                    Text("Nobody typing")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(model.typingUsers.sorted(), id: \.self) { user in
                        Label(user, systemImage: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
    }

    // "Unsubscribe All" / "Subscribe All" — the main new feature showcase
    private var bulkControls: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    model.unsubscribeAll()
                }
            } label: {
                Label("Unsubscribe All", systemImage: "bell.slash.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(model.activeSubscriptionCount > 0 ? 0.12 : 0.05))
                    .foregroundStyle(model.activeSubscriptionCount > 0 ? Color.red : Color.secondary)
                    .clipShape(.rect(cornerRadius: 10))
            }
            .disabled(model.activeSubscriptionCount == 0)
            .animation(.easeInOut(duration: 0.2), value: model.activeSubscriptionCount)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    model.subscribeAll()
                }
            } label: {
                Label("Subscribe All", systemImage: "bell.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(model.activeSubscriptionCount < 3 ? 0.12 : 0.05))
                    .foregroundStyle(model.activeSubscriptionCount < 3 ? Color.green : Color.secondary)
                    .clipShape(.rect(cornerRadius: 10))
            }
            .disabled(model.activeSubscriptionCount == 3)
            .animation(.easeInOut(duration: 0.2), value: model.activeSubscriptionCount)
        }
    }

    // MARK: Event Log

    private var eventLogSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Event Log", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.bold())
                    Spacer()
                    if !model.eventLog.isEmpty {
                        Button("Clear") { model.clearLog() }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.eventLog.isEmpty {
                    Text("Tap a publisher button to fire an event.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(model.eventLog) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.time, style: .time)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .leading)
                            Text(entry.text)
                                .font(.caption)
                                .foregroundStyle(entry.color)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Supporting Views

private struct EventButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    init(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tint.opacity(0.12))
                .foregroundStyle(tint)
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}

private struct SubscriberCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let isSubscribed: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
                Button(action: onToggle) {
                    Image(systemName: isSubscribed ? "bell.fill" : "bell.slash.fill")
                        .font(.caption)
                        .foregroundStyle(isSubscribed ? tint : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSubscribed ? "Unsubscribe \(title)" : "Subscribe \(title)")
            }

            Divider()

            Group {
                if isSubscribed {
                    content
                } else {
                    Label("Unsubscribed", systemImage: "bell.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.2), value: isSubscribed)
        }
        .padding(10)
        .background(tint.opacity(isSubscribed ? 0.06 : 0.02))
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSubscribed ? tint.opacity(0.2) : Color.secondary.opacity(0.15), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: isSubscribed)
    }
}

#Preview {
    EventBusDemoView()
}
