import Foundation

/// Persistence for the handful of facts the policy needs.
public protocol AfterglowStore: AnyObject, Sendable {
    /// The newest app version this user has opened, recorded after every evaluation.
    var lastSeenVersion: String? { get set }
    /// The version for which the review screen was last shown (at most once per minor version).
    var reviewScreenShownForVersion: String? { get set }
    /// When the user last tapped the write-review button; drives the cooldown.
    var lastWriteReviewTap: Date? { get set }
    /// When Afterglow first ran; used for the minimum install age.
    var firstLaunchDate: Date? { get set }
    /// Forgets everything this store holds.
    func removeAll()
}

/// Plain value copy of the store, fed to the pure decision function.
struct AfterglowSnapshot: Equatable, Sendable {
    var lastSeenVersion: String?
    var reviewScreenShownForVersion: String?
    var lastWriteReviewTap: Date?
    var firstLaunchDate: Date?

    init(
        lastSeenVersion: String? = nil,
        reviewScreenShownForVersion: String? = nil,
        lastWriteReviewTap: Date? = nil,
        firstLaunchDate: Date? = nil
    ) {
        self.lastSeenVersion = lastSeenVersion
        self.reviewScreenShownForVersion = reviewScreenShownForVersion
        self.lastWriteReviewTap = lastWriteReviewTap
        self.firstLaunchDate = firstLaunchDate
    }
}

extension AfterglowStore {
    var snapshot: AfterglowSnapshot {
        AfterglowSnapshot(
            lastSeenVersion: lastSeenVersion,
            reviewScreenShownForVersion: reviewScreenShownForVersion,
            lastWriteReviewTap: lastWriteReviewTap,
            firstLaunchDate: firstLaunchDate
        )
    }
}

/// Keys are prefixed `afterglow.`.
public final class UserDefaultsAfterglowStore: AfterglowStore, @unchecked Sendable {
    enum Key {
        static let lastSeenVersion = "afterglow.lastSeenVersion"
        static let reviewScreenShownForVersion = "afterglow.reviewScreenShownForVersion"
        static let lastWriteReviewTap = "afterglow.lastWriteReviewTap"
        static let firstLaunchDate = "afterglow.firstLaunchDate"
        static let all = [lastSeenVersion, reviewScreenShownForVersion, lastWriteReviewTap, firstLaunchDate]
    }

    private let defaults: UserDefaults

    /// Creates a store backed by `defaults` (the standard defaults unless you pass a suite).
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The newest app version this user has opened.
    public var lastSeenVersion: String? {
        get { defaults.string(forKey: Key.lastSeenVersion) }
        set { defaults.set(newValue, forKey: Key.lastSeenVersion) }
    }

    /// The version for which the review screen was last shown.
    public var reviewScreenShownForVersion: String? {
        get { defaults.string(forKey: Key.reviewScreenShownForVersion) }
        set { defaults.set(newValue, forKey: Key.reviewScreenShownForVersion) }
    }

    /// When the user last tapped the write-review button.
    public var lastWriteReviewTap: Date? {
        get { defaults.object(forKey: Key.lastWriteReviewTap) as? Date }
        set { defaults.set(newValue, forKey: Key.lastWriteReviewTap) }
    }

    /// When Afterglow first ran.
    public var firstLaunchDate: Date? {
        get { defaults.object(forKey: Key.firstLaunchDate) as? Date }
        set { defaults.set(newValue, forKey: Key.firstLaunchDate) }
    }

    /// Removes every `afterglow.` key from the defaults.
    public func removeAll() {
        Key.all.forEach { defaults.removeObject(forKey: $0) }
    }
}

/// Thread-safe in-memory store, for tests and previews.
public final class InMemoryAfterglowStore: AfterglowStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values = AfterglowSnapshot()

    /// Creates an empty store.
    public init() {}

    private func read<T>(_ keyPath: KeyPath<AfterglowSnapshot, T>) -> T {
        lock.lock(); defer { lock.unlock() }
        return values[keyPath: keyPath]
    }

    private func write<T>(_ keyPath: WritableKeyPath<AfterglowSnapshot, T>, _ value: T) {
        lock.lock(); defer { lock.unlock() }
        values[keyPath: keyPath] = value
    }

    /// The newest app version this user has opened.
    public var lastSeenVersion: String? {
        get { read(\.lastSeenVersion) }
        set { write(\.lastSeenVersion, newValue) }
    }

    /// The version for which the review screen was last shown.
    public var reviewScreenShownForVersion: String? {
        get { read(\.reviewScreenShownForVersion) }
        set { write(\.reviewScreenShownForVersion, newValue) }
    }

    /// When the user last tapped the write-review button.
    public var lastWriteReviewTap: Date? {
        get { read(\.lastWriteReviewTap) }
        set { write(\.lastWriteReviewTap, newValue) }
    }

    /// When Afterglow first ran.
    public var firstLaunchDate: Date? {
        get { read(\.firstLaunchDate) }
        set { write(\.firstLaunchDate, newValue) }
    }

    /// Removes every `afterglow.` key from the defaults.
    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        values = AfterglowSnapshot()
    }
}
