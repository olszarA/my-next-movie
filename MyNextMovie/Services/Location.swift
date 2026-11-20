import CoreLocation

/// How long the app waits for a fresh location.
private let locationTimeoutSeconds = 10

/// A fresh location. `fallbackUserLocation` when the user said no or after 10 seconds.
/// Has the type `UserLocationFinder`.
func findUserLocation() async -> UserLocation {
    return await withTaskGroup(of: UserLocation.self) { group in
        group.addTask { await waitForLocationUpdate() }
        group.addTask { await waitForTimeout() }
        // The first task to finish wins, the other one is cancelled.
        let firstLocation = await group.next() ?? fallbackUserLocation
        group.cancelAll()
        return firstLocation
    }
}

/// The last location the phone knows, at once. Has the type `LastKnownLocationReader`.
func lastKnownUserLocation() -> UserLocation {
    guard let location = CLLocationManager().location else {
        return fallbackUserLocation
    }
    return userLocationFromCoreLocation(location)
}

private func userLocationFromCoreLocation(_ location: CLLocation) -> UserLocation {
    return UserLocation(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude,
        isKnown: true
    )
}

/// The session asks for the permission the first time.
private func waitForLocationUpdate() async -> UserLocation {
    let session = CLServiceSession(authorization: .whenInUse)
    defer { session.invalidate() }
    do {
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location {
                return userLocationFromCoreLocation(location)
            }
            if update.authorizationDenied || update.authorizationDeniedGlobally {
                return fallbackUserLocation
            }
        }
    } catch {
        return fallbackUserLocation
    }
    return fallbackUserLocation
}

private func waitForTimeout() async -> UserLocation {
    try? await Task.sleep(for: .seconds(locationTimeoutSeconds))
    return fallbackUserLocation
}
