# EventBus

A lightweight, type-safe event bus for Swift — built for in-process publish/subscribe communication with automatic memory management.

## Features

- **Type-safe events** — each event is a distinct `Sendable` struct; no string keys or `Any` casting in call sites
- **Weak-ownership subscriptions** — handlers are automatically removed when the owner is deallocated
- **`SubscriptionToken`** — hold the returned token to cancel a specific subscription at any time
- **`unsubscribeAll(for:)`** — cancel every subscription held by an owner in one call, without needing individual tokens
- **Thread-safe** — all internal state is protected by `NSLock`; publish/subscribe can be called from any thread

## Quick start

### 1. Define an event

```swift
struct MessageReceivedEvent: EventBusEvent {
    let sender: String
    let text: String
}
```

### 2. Subscribe

```swift
class InboxViewController: UIViewController {
    private var token: EventBus.SubscriptionToken?

    override func viewDidLoad() {
        super.viewDidLoad()
        token = EventBus.shared.subscribe(
            owner: self,
            eventType: MessageReceivedEvent.self
        ) { owner, event in
            owner.showMessage(from: event.sender, text: event.text)
        }
    }
}
```

The closure captures `owner` weakly — no retain cycles, no manual cleanup needed if the view controller is dismissed.

### 3. Publish

```swift
EventBus.shared.publish(MessageReceivedEvent(sender: "Alice", text: "Hey there!"))
// All active subscribers receive the event synchronously on the calling thread.
```

### 4. Cancel a specific subscription

```swift
token?.cancel()
```

### 5. Cancel all subscriptions for an owner

```swift
EventBus.shared.unsubscribeAll(for: self)
// Removes every subscription this owner holds — no tokens required.
```

## How it works

```
Publisher                 EventBus                  Subscribers
   │                         │                           │
   │──publish(event)─────────►│                           │
   │                         │──handler(owner, event)───►│ Inbox
   │                         │──handler(owner, event)───►│ Presence
   │                         │──handler(owner, event)───►│ Typing
   │                         │                           │
   │                   (synchronous,                      │
   │                    in-process,                       │
   │                    no broker)                        │
```

Receivers are collected under a lock, then called outside it — so publishing is safe even if a handler cancels its own subscription.

Dead subscriptions (owner deallocated or token cancelled) are pruned lazily on the next `publish` call for that event type.

## EventBus vs Kafka

| Feature | EventBus | Kafka |
|---------|----------|-------|
| Scope | In-process | Distributed |
| Broker | ❌ None | ✅ Required |
| Persistence | ❌ Ephemeral | ✅ Durable log |
| Delivery | Synchronous | Asynchronous |
| Event replay | ❌ | ✅ Any offset |
| Consumer groups | ❌ | ✅ Independent |
| Latency | ✅ ~μs | ~ms |
| Setup | ✅ Zero-config | Infrastructure |
| Memory safety | ✅ Weak refs | N/A |

**Use EventBus when** you need fast, zero-infrastructure communication between components within a single app — tab changes, modal coordination, feature-flag updates, analytics triggers.

**Use Kafka when** you need cross-service messaging, event replay, independent consumer groups, or durability across process restarts.

## Demo app

The included Xcode project ships two tabs:

| Tab | What it shows |
|-----|---------------|
| **Live Demo** | Fire `MessageReceivedEvent`, `UserStatusChangedEvent`, and `TypingIndicatorEvent`. Toggle individual subscriptions on/off via bell buttons. Use **Unsubscribe All** to cancel all three at once with a single `unsubscribeAll(for:)` call, then **Subscribe All** to restore them. |
| **vs Kafka** | Animated side-by-side architecture diagram. Tap **Fire Event** to see EventBus deliver synchronously in ~800 ms while Kafka persists to a durable log and delivers asynchronously over ~2 s. Includes a feature comparison table and "when to use" recommendations. |

## Requirements

- iOS 17+ / macOS 14+
- Swift 5.9+
- Xcode 15+

## License

MIT — see [LICENSE](LICENSE).
