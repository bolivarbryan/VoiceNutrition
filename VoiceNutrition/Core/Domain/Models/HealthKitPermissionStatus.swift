/// The status of HealthKit authorization.
public enum HealthKitPermissionStatus: Sendable, Equatable {
    /// User has authorized HealthKit access.
    case authorized
    /// User has denied HealthKit access.
    case denied
    /// User has not yet been asked for HealthKit access.
    case notDetermined
}
