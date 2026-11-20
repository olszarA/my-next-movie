import MapKit

/// The part of the map that shows every cinema.
let wroclawMapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 51.0956, longitude: 17.0230),
    latitudinalMeters: 15500,
    longitudinalMeters: 14000
)

/// The same size, a new center.
func regionMoved(_ region: MKCoordinateRegion, to center: CLLocationCoordinate2D)
    -> MKCoordinateRegion
{
    return MKCoordinateRegion(center: center, span: region.span)
}

func isInRegion(_ coordinate: CLLocationCoordinate2D, _ region: MKCoordinateRegion) -> Bool {
    let halfLatitudeDelta = region.span.latitudeDelta / 2
    let halfLongitudeDelta = region.span.longitudeDelta / 2
    let latitudeOffset = abs(coordinate.latitude - region.center.latitude)
    let longitudeOffset = abs(coordinate.longitude - region.center.longitude)
    return latitudeOffset <= halfLatitudeDelta && longitudeOffset <= halfLongitudeDelta
}
