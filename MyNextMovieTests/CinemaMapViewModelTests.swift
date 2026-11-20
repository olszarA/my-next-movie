import MapKit
import Testing

@testable import MyNextMovie

/// Near Helios Magnolia, far from the station.
@MainActor
private let westWroclawLocation = UserLocation(latitude: 51.1188, longitude: 16.9906, isKnown: true)

@MainActor
struct CinemaMapViewModelTests {
    @Test func showsCinemasAtOnceByName() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        #expect(
            namesOf(viewModel.cinemas) == [
                "DCF", "Helios Magnolia", "Kino Nowe Horyzonty", "Multikino Pasaż Grunwaldzki",
            ])
        #expect(!viewModel.isLocationUnavailable)
    }

    @Test func sortsByDistanceOnceUserIsFound() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        await viewModel.locateUser()

        #expect(viewModel.cinemas.first?.id == testCinemaDCF.id)
        #expect(viewModel.userLocation == testUserLocation)
    }

    @Test func lastKnownLocationIsUsedWhenNoFreshOneComes() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { fallbackUserLocation },
            lastKnownLocation: { testUserLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(viewModel.cinemas.first?.id == testCinemaDCF.id)
    }

    @Test func freshLocationReplacesLastKnownOne() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { testUserLocation },
            lastKnownLocation: { westWroclawLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(viewModel.cinemas.first?.id == testCinemaDCF.id)
    }

    @Test func saysWhenLocationIsUnavailable() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { fallbackUserLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.isLocationUnavailable)
        #expect(namesOf(viewModel.cinemas).first == "DCF")
        #expect(viewModel.cinemas.first?.distanceInMeters == unknownDistance)
    }

    @Test func asksForLocationOnlyOnce() async {
        var askCount = 0
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: {
                askCount += 1
                return testUserLocation
            }
        )

        await viewModel.locateUserIfNeeded()
        await viewModel.locateUserIfNeeded()

        #expect(askCount == 1)
    }

    @Test func togglesSelection() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        viewModel.toggleCinema(testCinemaHelios)
        #expect(viewModel.selectedCinemaId == testCinemaHelios.id)

        viewModel.toggleCinema(testCinemaDCF)
        #expect(viewModel.selectedCinemaId == testCinemaDCF.id)

        viewModel.toggleCinema(testCinemaDCF)
        #expect(viewModel.selectedCinemaId == noCinemaSelected)
    }
}

@MainActor
private func makeRoute(distanceInMeters: CLLocationDistance, travelTime: TimeInterval)
    -> CinemaRoute
{
    return CinemaRoute(
        line: MKPolyline(), distanceInMeters: distanceInMeters, travelTime: travelTime)
}

@MainActor
struct CinemaDetailViewModelTests {
    @Test func findsNoRouteWithoutLocation() async {
        var routeRequestCount = 0
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: fallbackUserLocation,
            findRoute: { _, _, _ in
                routeRequestCount += 1
                return noRoute
            }
        )

        await viewModel.loadRoute()

        #expect(!viewModel.canFindRoute)
        #expect(routeRequestCount == 0)
        #expect(viewModel.routeState == .idle)
    }

    @Test func findsRouteForSelectedTravelMode() async {
        var askedTravelModes: [TravelMode] = []
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: testUserLocation,
            findRoute: { _, _, travelMode in
                askedTravelModes.append(travelMode)
                return makeRoute(distanceInMeters: 1200, travelTime: 240)
            }
        )

        viewModel.travelMode = .driving
        await viewModel.loadRoute()

        #expect(askedTravelModes == [.driving])
        #expect(viewModel.routeState == .loaded)
        #expect(viewModel.route.distanceInMeters == 1200)
    }

    @Test func showsErrorWhenRouteFails() async {
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: testUserLocation,
            findRoute: { _, _, _ in throw NoRouteFound() }
        )

        await viewModel.loadRoute()

        #expect(viewModel.routeState == .failed)
        #expect(viewModel.errorMessage == "Maps found no way to this cinema.")
    }

    @Test func routeSummaryHasTimeAndDistance() {
        let route = makeRoute(distanceInMeters: 950, travelTime: 720)

        #expect(routeSummary(route) == "12 min \u{00B7} 950 m")
        #expect(formattedTravelTime(4500) == "1 h 15 min")
    }
}
