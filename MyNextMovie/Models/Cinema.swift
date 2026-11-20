import CoreLocation
import Foundation

// Lab 6: the data types of the Cinemas tab are ready.
// Write the other constants and the functions from task 1 in this file.

/// Distance of a cinema before the app knows where the user is.
nonisolated let unknownDistance: CLLocationDistance = -1

/// A cinema in Wrocław, a plain struct,
/// so the views and tests do not depend on `MKMapItem`.
nonisolated struct Cinema: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String  // empty when unknown
    let phoneNumber: String  // empty when unknown
    let website: String  // empty when unknown
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    var distanceInMeters = unknownDistance
}

/// Where the user is. `isKnown` is false when the app does not know it.
nonisolated struct UserLocation: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let isKnown: Bool
}

let noCinemaSelected = ""
let cinemaNotFound = -1

// The Market Square, when the location is unknown.
let fallbackCoordinate = CLLocationCoordinate2D(latitude: 51.1100, longitude: 17.0320)
let fallbackUserLocation = UserLocation(
    latitude: fallbackCoordinate.latitude,
    longitude: fallbackCoordinate.longitude,
    isKnown: false
)

private let metersPerKilometer: CLLocationDistance = 1000
private let kilometersFormat = "%.1f km"
private let phoneURLPrefix = "tel:"
/// The only characters a `tel:` link keeps from a phone number.
private let phoneNumberCharacters = "+0123456789"

func cinemaCoordinate(_ cinema: Cinema) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: cinema.latitude, longitude: cinema.longitude)
}

func userCoordinate(_ userLocation: UserLocation) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(
        latitude: userLocation.latitude, longitude: userLocation.longitude)
}

/// In a straight line, not along the streets.
func distanceInMeters(from userLocation: UserLocation, to cinema: Cinema) -> CLLocationDistance {
    let userPlace = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
    let cinemaPlace = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    return userPlace.distance(from: cinemaPlace)
}

/// The cinemas with their distance from the user, the closest first.
func cinemasSortedByDistance(_ cinemas: [Cinema], from userLocation: UserLocation) -> [Cinema] {
    var measuredCinemas: [Cinema] = []
    for cinema in cinemas {
        var measuredCinema = cinema
        measuredCinema.distanceInMeters = distanceInMeters(from: userLocation, to: cinema)
        measuredCinemas.append(measuredCinema)
    }
    return measuredCinemas.sorted(by: isCloser)
}

/// The closer cinema first, by name when both are as far.
/// Before the location is known every distance is `unknownDistance`, so the order is by name.
func isCloser(_ first: Cinema, _ second: Cinema) -> Bool {
    if first.distanceInMeters != second.distanceInMeters {
        return first.distanceInMeters < second.distanceInMeters
    }
    return first.name.localizedStandardCompare(second.name) == .orderedAscending
}

/// The index of the cinema in the list, `cinemaNotFound` when it is not there.
func positionOfCinema(_ cinemas: [Cinema], cinemaId: String) -> Int {
    for index in cinemas.indices {
        if cinemas[index].id == cinemaId {
            return index
        }
    }
    return cinemaNotFound
}

func containsCinema(_ cinemas: [Cinema], cinemaId: String) -> Bool {
    return positionOfCinema(cinemas, cinemaId: cinemaId) != cinemaNotFound
}

/// "850 m", "2.4 km", "" for `unknownDistance`.
func formattedDistance(_ distance: CLLocationDistance) -> String {
    if distance < 0 {
        return ""
    }
    let roundedMeters = Int(distance.rounded())
    if roundedMeters < Int(metersPerKilometer) {
        return "\(roundedMeters) m"
    }
    return String(format: kilometersFormat, distance / metersPerKilometer)
}

/// "+48 71 796 34 87" -> "tel:+48717963487", nil when the cinema has no number.
func phoneURL(_ cinema: Cinema) -> URL? {
    var dialedNumber = ""
    for character in cinema.phoneNumber {
        if phoneNumberCharacters.contains(character) {
            dialedNumber.append(character)
        }
    }
    if dialedNumber.isEmpty {
        return nil
    }
    return URL(string: phoneURLPrefix + dialedNumber)
}

func hasPhoneNumber(_ cinema: Cinema) -> Bool {
    return phoneURL(cinema) != nil
}

func websiteURL(_ cinema: Cinema) -> URL? {
    if cinema.website.isEmpty {
        return nil
    }
    return URL(string: cinema.website)
}

func hasWebsite(_ cinema: Cinema) -> Bool {
    return websiteURL(cinema) != nil
}
