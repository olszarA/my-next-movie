import MapKit
import Observation

/// The cinemas of the Cinemas tab, the closest first once the user is found.
/// A class only because SwiftUI's @Observable requires one.
@Observable
final class CinemaMapViewModel {
    private(set) var cinemas: [Cinema]
    private(set) var userLocation = fallbackUserLocation
    /// `noCinemaSelected` when no cinema is selected. The map pins change it too.
    var selectedCinemaId = noCinemaSelected
    private(set) var isLocating = false
    /// What the map shows now, so a tapped row moves the map without zooming it.
    var visibleRegion = wroclawMapRegion

    private let findUserLocation: UserLocationFinder
    private let lastKnownLocation: LastKnownLocationReader
    private var hasAskedForLocation = false

    init(
        cinemas: [Cinema],
        findUserLocation: @escaping UserLocationFinder,
        lastKnownLocation: @escaping LastKnownLocationReader = { fallbackUserLocation }
    ) {
        // Every distance is unknown yet, so this sorts by name.
        self.cinemas = cinemas.sorted(by: isCloser)
        self.findUserLocation = findUserLocation
        self.lastKnownLocation = lastKnownLocation
    }

    /// The app asked, but has no location: no permission, or no answer in time.
    var isLocationUnavailable: Bool {
        return hasAskedForLocation && !isLocating && !userLocation.isKnown
    }

    /// The last known location at once, then a fresh one.
    func locateUser() async {
        hasAskedForLocation = true
        isLocating = true
        useLocation(lastKnownLocation())
        let freshLocation = await findUserLocation()
        useLocation(freshLocation)
        isLocating = false
    }

    /// The tab appears many times, but asks for the location once.
    func locateUserIfNeeded() async {
        if hasAskedForLocation {
            return
        }
        await locateUser()
    }

    /// Selects the cinema, or clears the selection when it is already selected.
    func toggleCinema(_ cinema: Cinema) {
        if selectedCinemaId == cinema.id {
            selectedCinemaId = noCinemaSelected
            return
        }
        selectedCinemaId = cinema.id
    }

    /// An unknown location does not replace a known one.
    private func useLocation(_ location: UserLocation) {
        if !location.isKnown {
            return
        }
        userLocation = location
        cinemas = cinemasSortedByDistance(cinemas, from: location)
    }
}
