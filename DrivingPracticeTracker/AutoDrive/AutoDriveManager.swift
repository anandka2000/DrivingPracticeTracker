import Foundation
import Combine
import CoreMotion
import CoreLocation

@MainActor
class AutoDriveManager: NSObject, ObservableObject {
    static let shared = AutoDriveManager()

    @Published var isDriving = false
    @Published var showStartBanner = false
    @Published var showEndPrompt = false
    @Published var pendingSession: DetectedSession?

    struct DetectedSession {
        var date: Date
        var durationMinutes: Int
        var conditions: [DrivingCondition]
    }

    private let activityManager = CMMotionActivityManager()
    private let locationManager = CLLocationManager()
    private var driveStartTime: Date?
    private var maxSpeedMph: Double = 0
    private var stopDebounceTask: Task<Void, Never>?
    private var userConfirmedSession = false

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 30
    }

    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            Task { @MainActor in self.process(activity: activity) }
        }
    }

    func stopMonitoring() {
        activityManager.stopActivityUpdates()
        locationManager.stopUpdatingLocation()
        stopDebounceTask?.cancel()
    }

    func userConfirmedDriveStart() {
        userConfirmedSession = true
        showStartBanner = false
    }

    func userDismissedDriveStart() {
        userConfirmedSession = false
        showStartBanner = false
        driveStartTime = nil
        isDriving = false
        locationManager.stopUpdatingLocation()
    }

    func saveDetectedSession() -> DetectedSession? {
        let s = pendingSession
        pendingSession = nil
        showEndPrompt = false
        userConfirmedSession = false
        return s
    }

    func dismissEndPrompt() {
        pendingSession = nil
        showEndPrompt = false
        userConfirmedSession = false
    }

    private func process(activity: CMMotionActivity) {
        if activity.automotive && activity.confidence != .low {
            driveDetected(at: activity.startDate)
        } else if isDriving && !activity.automotive {
            stopDebounceTask?.cancel()
            stopDebounceTask = Task {
                try? await Task.sleep(for: .seconds(180))
                if !Task.isCancelled { await MainActor.run { self.driveEnded() } }
            }
        }
    }

    private func driveDetected(at startDate: Date) {
        stopDebounceTask?.cancel()
        guard !isDriving else { return }
        isDriving = true
        driveStartTime = startDate
        maxSpeedMph = 0
        userConfirmedSession = false
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        showStartBanner = true
    }

    private func driveEnded() {
        guard isDriving, let startTime = driveStartTime else { return }
        isDriving = false
        locationManager.stopUpdatingLocation()
        showStartBanner = false
        guard userConfirmedSession else { return }
        let endTime = Date()
        let durationMinutes = max(Int(endTime.timeIntervalSince(startTime) / 60), 1)
        var conditions: [DrivingCondition] = []
        let hour = Calendar.current.component(.hour, from: startTime)
        conditions.append(hour >= 18 || hour < 6 ? .night : .day)
        if maxSpeedMph > 45 { conditions.append(.highway) }
        pendingSession = DetectedSession(date: startTime, durationMinutes: durationMinutes, conditions: conditions)
        showEndPrompt = true
    }
}

extension AutoDriveManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.speed >= 0 else { return }
        let mph = loc.speed * 2.23694
        Task { @MainActor in if mph > self.maxSpeedMph { self.maxSpeedMph = mph } }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in if self.isDriving { self.locationManager.startUpdatingLocation() } }
        }
    }
}
