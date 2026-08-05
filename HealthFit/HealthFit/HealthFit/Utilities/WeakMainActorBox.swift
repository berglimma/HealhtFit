import Foundation

/// Holds a weak object reference in a Sendable box so concurrent callbacks
/// (Timer, HealthKit, CoreMotion, etc.) can hop to the main actor without
/// capturing a Swift 6 `var self` from an outer `[weak self]` list.
final class WeakMainActorBox<T: AnyObject>: @unchecked Sendable {
    private weak var object: T?

    init(_ object: T) {
        self.object = object
    }

    /// Schedule work on the main actor if the object is still alive.
    func run(_ body: @MainActor @escaping (T) -> Void) {
        Task { @MainActor in
            guard let object else { return }
            body(object)
        }
    }

    /// Async main-actor work (awaits the body so callers can process sequentially).
    func runAsync(_ body: @MainActor @escaping (T) async -> Void) async {
        guard let object else { return }
        await body(object)
    }
}

extension WeakMainActorBox {
    /// Convenience for firing from a timer / motion / HK callback.
    static func schedule(_ object: T?, _ body: @MainActor @escaping (T) -> Void) {
        guard let object else { return }
        WeakMainActorBox(object).run(body)
    }
}
