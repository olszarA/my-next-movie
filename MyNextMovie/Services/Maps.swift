import MapKit

// Location and routes as plain function types, so the view models can be tested
// without Core Location and MapKit, like `MovieLoader`.

typealias UserLocationFinder = () async -> UserLocation
typealias LastKnownLocationReader = () -> UserLocation

nonisolated enum TravelMode {
    case walking
    case driving
}

/// `@MainActor`, because `CinemaRoute` holds an `MKPolyline`,
/// so the route stays on the main thread.
typealias CinemaRouteFinder =
    @MainActor (UserLocation, Cinema, TravelMode) async throws -> CinemaRoute

struct CinemaRoute {
    let line: MKPolyline
    let distanceInMeters: CLLocationDistance
    let travelTime: TimeInterval
}

/// Shown before a route is found.
let noRoute = CinemaRoute(line: MKPolyline(), distanceInMeters: 0, travelTime: 0)

nonisolated struct NoRouteFound: LocalizedError {
    var errorDescription: String? {
        return "Maps found no way to this cinema."
    }
}

/// The first route Apple Maps finds. Has the type `CinemaRouteFinder`.
func findMapKitRoute(
    userLocation: UserLocation,
    cinema: Cinema,
    travelMode: TravelMode
) async throws -> CinemaRoute {
    let request = MKDirections.Request()
    let userPlace = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
    request.source = MKMapItem(location: userPlace, address: nil)
    request.destination = mapItemForCinema(cinema)
    request.transportType = transportTypeForMapKit(travelMode)
    let response = try await MKDirections(request: request).calculate()
    guard let firstRoute = response.routes.first else {
        throw NoRouteFound()
    }
    return CinemaRoute(
        line: firstRoute.polyline,
        distanceInMeters: firstRoute.distance,
        travelTime: firstRoute.expectedTravelTime
    )
}

func mapItemForCinema(_ cinema: Cinema) -> MKMapItem {
    let cinemaPlace = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    let address = MKAddress(fullAddress: cinema.address, shortAddress: nil)
    let mapItem = MKMapItem(location: cinemaPlace, address: address)
    mapItem.name = cinema.name
    return mapItem
}

func transportTypeForMapKit(_ travelMode: TravelMode) -> MKDirectionsTransportType {
    switch travelMode {
    case .walking:
        return .walking
    case .driving:
        return .automobile
    }
}

/// Opens Apple Maps with the way from the user to the cinema.
func openCinemaInMaps(_ cinema: Cinema, travelMode: TravelMode) {
    let launchOptions = [MKLaunchOptionsDirectionsModeKey: directionsModeForMaps(travelMode)]
    mapItemForCinema(cinema).openInMaps(launchOptions: launchOptions)
}

/// Photos of the street at the cinema, nil when Apple has none there.
func findLookAroundScene(_ cinema: Cinema) async -> MKLookAroundScene? {
    let request = MKLookAroundSceneRequest(coordinate: cinemaCoordinate(cinema))
    return try? await request.scene
}

private func directionsModeForMaps(_ travelMode: TravelMode) -> String {
    switch travelMode {
    case .walking:
        return MKLaunchOptionsDirectionsModeWalking
    case .driving:
        return MKLaunchOptionsDirectionsModeDriving
    }
}
