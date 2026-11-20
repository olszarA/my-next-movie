import CoreLocation
import MapKit
import Testing

@testable import MyNextMovie

@MainActor
struct CinemaTests {
    @Test func sortsCinemasClosestFirst() {
        let sortedCinemas = cinemasSortedByDistance(testCinemas, from: testUserLocation)

        #expect(
            namesOf(sortedCinemas) == [
                "DCF", "Kino Nowe Horyzonty", "Multikino Pasaż Grunwaldzki", "Helios Magnolia",
            ])
    }

    @Test func measuresDistanceOfEveryCinema() {
        let sortedCinemas = cinemasSortedByDistance(testCinemas, from: testUserLocation)

        for cinema in sortedCinemas {
            #expect(cinema.distanceInMeters > 0)
        }
        // DCF is about 800 m from the station in a straight line.
        let dcfDistance = distanceInMeters(from: testUserLocation, to: testCinemaDCF)
        #expect(dcfDistance > 700 && dcfDistance < 900)
    }

    @Test func sortsCinemasAtTheSameDistanceByName() {
        let twin = Cinema(
            id: "twin",
            name: "Atlantic",
            address: "",
            phoneNumber: "",
            website: "",
            latitude: testCinemaDCF.latitude,
            longitude: testCinemaDCF.longitude
        )

        let sortedCinemas = cinemasSortedByDistance([testCinemaDCF, twin], from: testUserLocation)

        #expect(namesOf(sortedCinemas) == ["Atlantic", "DCF"])
    }

    @Test func findsPositionOfCinema() {
        #expect(positionOfCinema(testCinemas, cinemaId: testCinemaDCF.id) == 2)
        #expect(positionOfCinema(testCinemas, cinemaId: "no-such-cinema") == cinemaNotFound)
        #expect(containsCinema(testCinemas, cinemaId: testCinemaHelios.id))
        #expect(!containsCinema(testCinemas, cinemaId: noCinemaSelected))
    }

    @Test func unknownDistanceIsEmptyText() {
        #expect(formattedDistance(unknownDistance) == "")
        #expect(formattedDistance(850) == "850 m")
        #expect(formattedDistance(2400) == "2.4 km")
    }

    @Test func phoneLinkHasOnlyDigits() {
        #expect(phoneURL(testCinemaNoweHoryzonty) == URL(string: "tel:+48717864566"))
        #expect(hasPhoneNumber(testCinemaNoweHoryzonty))
    }

    @Test func noPhoneOrWebsiteMeansNoLink() {
        #expect(phoneURL(testCinemaDCF) == nil)
        #expect(!hasPhoneNumber(testCinemaDCF))
        #expect(websiteURL(testCinemaDCF) == nil)
        #expect(!hasWebsite(testCinemaDCF))
    }
}

@MainActor
struct WroclawCinemasTests {
    @Test func everyCinemaIsOnTheStartMap() {
        for cinema in wroclawCinemas {
            #expect(isInRegion(cinemaCoordinate(cinema), wroclawMapRegion), "\(cinema.name)")
        }
    }

    @Test func idsAreUnique() {
        var ids: [String] = []
        for cinema in wroclawCinemas {
            #expect(!ids.contains(cinema.id))
            ids.append(cinema.id)
        }
    }

    @Test func everyCinemaHasAddressAndWebsite() {
        for cinema in wroclawCinemas {
            #expect(!cinema.address.isEmpty)
            #expect(hasWebsite(cinema))
        }
    }

    @Test func pointOutsideRegionIsNotOnTheMap() {
        let krakow = CLLocationCoordinate2D(latitude: 50.0614, longitude: 19.9366)

        #expect(!isInRegion(krakow, wroclawMapRegion))
        #expect(isInRegion(wroclawMapRegion.center, wroclawMapRegion))
    }
}

@MainActor
struct MapKitConversionTests {
    @Test func mapItemForCinemaKeepsNameAndPosition() {
        let mapItem = mapItemForCinema(testCinemaDCF)

        #expect(mapItem.name == testCinemaDCF.name)
        #expect(mapItem.location.coordinate.latitude == testCinemaDCF.latitude)
        #expect(mapItem.location.coordinate.longitude == testCinemaDCF.longitude)
    }

    @Test func travelModeBecomesMapKitTransportType() {
        #expect(transportTypeForMapKit(.walking) == .walking)
        #expect(transportTypeForMapKit(.driving) == .automobile)
    }
}
