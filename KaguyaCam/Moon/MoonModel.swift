import Foundation
import CoreLocation
import Combine

/// 現在地と時刻から、昨夜・今夜・明晩の月の状態を計算して配信する。
final class MoonModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var today: MoonEphemeris.State?
    @Published var yesterday: MoonEphemeris.State?
    @Published var tomorrow: MoonEphemeris.State?
    @Published var heading: Double = 0          // 端末が向く方位（真北=0）
    @Published var authorized = false
    @Published var hasLocation = false

    private let manager = CLLocationManager()
    private var location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671) // 既定=東京
    private var timer: Timer?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.headingFilter = 1
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        recompute()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.recompute()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        timer?.invalidate()
        timer = nil
    }

    /// 昨夜・今夜・明晩（同時刻）の月の状態を計算し直す。
    private func recompute() {
        let now = Date()
        let day: TimeInterval = 86400
        today = MoonEphemeris.state(date: now, latitude: location.latitude, longitude: location.longitude)
        yesterday = MoonEphemeris.state(date: now.addingTimeInterval(-day),
                                        latitude: location.latitude, longitude: location.longitude)
        tomorrow = MoonEphemeris.state(date: now.addingTimeInterval(day),
                                       latitude: location.latitude, longitude: location.longitude)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorized = true
        default:
            authorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc.coordinate
        hasLocation = true
        recompute()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}
