//
//  EventBus.swift
//  EventBusExample
//
//  Created by Rani Badri on 5/26/26.
//
import Foundation

protocol EventBusEvent: Sendable { }

class EventBus: @unchecked Sendable {
    private let lock = NSLock()
    private var subscriptionsByEvent: [ObjectIdentifier: [SubscriptionEntry]] = [:]
    
    /// Shared event bus instance.
    public static let shared = EventBus()
    
    func publish<Event: EventBusEvent>(_ event: Event) {
        let eventKey  = ObjectIdentifier(Event.self)
        let receivers: [(Any) -> Void] = lock.withLock {
            guard var bucket = subscriptionsByEvent[eventKey] else { return [] }

            bucket = cleanDeadSubscriptions(in: bucket)
            subscriptionsByEvent[eventKey] = bucket.isEmpty ? nil : bucket
            return bucket.map(\.subscription.receive)
        }
        receivers.forEach { $0(event) }
    }
    
    @discardableResult
    func subscribe<Owner: AnyObject, Event: EventBusEvent>(
        owner: Owner,
        eventType: Event.Type,
        using handler: @escaping (Owner,Event) -> Void
    ) -> SubscriptionToken {
        let eventKey = ObjectIdentifier(eventType)
        let cancellationState = CancellationState()
        let subscription = Subscription(
            owner: owner,
            cancellationState: cancellationState,
            handler: handler
        )
        let id = UUID()
        let entry = SubscriptionEntry(id: id, subscription: subscription)
        
        lock.withLock {
            var bucket = subscriptionsByEvent[eventKey] ?? []
            bucket.append(entry)
            subscriptionsByEvent[eventKey] = bucket
        }
        
        return SubscriptionToken(cancellationState: cancellationState, cancelClosure: { [weak self] in
            self?.removeSubscription(eventKey: eventKey, id: id)
        })
    }
    
    func cleanDeadSubscriptions(in bucket: [SubscriptionEntry]) -> [SubscriptionEntry] {
        bucket.filter {
            $0.subscription.isAlive && !$0.subscription.cancellationState.cancelled()
        }
    }
    
    func removeSubscription(eventKey: ObjectIdentifier, id: UUID) {
        lock.withLock {
            guard var bucket = subscriptionsByEvent[eventKey] else {
                return
            }

            guard let index = bucket.firstIndex(where: { $0.id == id }) else {
                return
            }

            bucket[index].subscription.cancelDelivery()
            bucket.remove(at: index)
            subscriptionsByEvent[eventKey] = bucket.isEmpty ? nil : bucket
        }
    }
    
    /// Unsubscribes `owner` from all event types.
    public func unsubscribeAll(for owner: AnyObject) {
        let ownerID = ObjectIdentifier(owner)

        lock.withLock {
            let eventKeys = Array(subscriptionsByEvent.keys)

            for eventKey in eventKeys {
                guard let bucket = subscriptionsByEvent[eventKey] else {
                    continue
                }

                var filtered: [SubscriptionEntry] = []
                filtered.reserveCapacity(bucket.count)

                for entry in bucket {
                    guard entry.subscription.isAlive else {
                        continue
                    }

                    if entry.subscription.belongs(to: ownerID) {
                        entry.subscription.cancelDelivery()
                    } else {
                        filtered.append(entry)
                    }
                }

                subscriptionsByEvent[eventKey] = filtered.isEmpty ? nil : filtered
            }
        }
    }
}



extension EventBus {
    
    struct SubscriptionEntry {
        let id: UUID
        let subscription: Subscription
    }
    
    final class CancellationState: @unchecked Sendable {
        private let lock = NSLock()
        private var isCancelled = false
        
        func cancel() {
            lock.lock()
            isCancelled = true
            lock.unlock()
        }
        
        func cancelled() -> Bool  {
            lock.lock()
            defer {
                lock.unlock()
            }
            return isCancelled
        }
    }
    
    final class Subscription {
        private weak var owner: AnyObject?
        let cancellationState: CancellationState
        let receive: (Any) -> Void
        
        init<Owner: AnyObject, Event: EventBusEvent>(
            owner: Owner,
            cancellationState: CancellationState,
            handler: @escaping (Owner, Event) -> Void
        ) {
            self.owner = owner
            self.cancellationState = cancellationState
            self.receive =  { [weak owner] rawEvent in
                guard !cancellationState.cancelled(),
                    let owner,
                    let event = rawEvent as? Event else { return }
                
                handler(owner, event)
            }
        }
        
        var isAlive: Bool {
            owner != nil
        }
        
        func cancelDelivery() {
            cancellationState.cancel()
        }
        
        func belongs(to ownerID: ObjectIdentifier) -> Bool {
            guard let owner else {
                return false
            }
            return ObjectIdentifier(owner) == ownerID
        }
    }
    
    final class SubscriptionToken: @unchecked Sendable {
        private let lock = NSLock()
        private let cancellationState: CancellationState
        private let cancelClosure: @Sendable () -> Void
        private var isCancelled = false
        
        init(cancellationState: CancellationState,
             cancelClosure: @Sendable @escaping () -> Void
        ) {
            self.cancellationState = cancellationState
            self.cancelClosure = cancelClosure
        }
        
        //cancels the associated subscription
        public func cancel() {
            lock.lock()
            guard !isCancelled else {
                lock.unlock()
                return
            }
            
            isCancelled = true
            lock.unlock()
            cancellationState.cancel()
            cancelClosure()
        }
    }
}



