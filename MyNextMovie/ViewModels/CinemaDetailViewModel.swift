import Foundation
import Observation

private let secondsPerMinute: TimeInterval = 60
private let minutesPerHourOfTravel = 60

/// One cinema and the way there. A class only because SwiftUI's @Observable requires one.
@Observable
final class CinemaDetailViewModel {
    let cinema: Cinema
    let userLocation: UserLocation
    var travelMode = TravelMode.walking
    private(set) var routeState = LoadState.idle
    private(set) var route = noRoute
    private(set) var errorMessage = ""

    private let findRoute: CinemaRouteFinder

    init(cinema: Cinema, userLocation: UserLocation, findRoute: @escaping CinemaRouteFinder) {
        self.cinema = cinema
        self.userLocation = userLocation
        self.findRoute = findRoute
    }

    /// A route needs a start, so it needs the location of the user.
    var canFindRoute: Bool {
        return userLocation.isKnown
    }

    /// The route for `travelMode`. Called again after every change of the travel mode.
    func loadRoute() async {
        if !canFindRoute {
            return
        }
        routeState = .loading
        do {
            route = try await findRoute(userLocation, cinema, travelMode)
            routeState = .loaded
        } catch {
            route = noRoute
            errorMessage = error.localizedDescription
            routeState = .failed
        }
    }
}

/// 720 -> "12 min", 4500 -> "1 h 15 min".
func formattedTravelTime(_ travelTime: TimeInterval) -> String {
    let minutes = Int((travelTime / secondsPerMinute).rounded())
    if minutes < minutesPerHourOfTravel {
        return "\(minutes) min"
    }
    let hours = minutes / minutesPerHourOfTravel
    let minutesAfterHours = minutes % minutesPerHourOfTravel
    return "\(hours) h \(minutesAfterHours) min"
}

/// "12 min · 950 m".
func routeSummary(_ route: CinemaRoute) -> String {
    let travelTime = formattedTravelTime(route.travelTime)
    let distance = formattedDistance(route.distanceInMeters)
    return travelTime + textSeparator + distance
}
