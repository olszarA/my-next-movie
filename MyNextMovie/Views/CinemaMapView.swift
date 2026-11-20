import MapKit
import SwiftUI

/// The map takes this part of the screen height, the list the rest.
private let mapHeightFraction: CGFloat = 0.45
private let selectedRowOpacity = 0.15

/// Where the cinema map is shown. Only the sheet has a "Done" button.
enum CinemaMapPlacement {
    case tab
    case sheet
}

/// Cinemas on the map and in a list. A pin selects its row, a row moves the map.
struct CinemaMapView: View {
    @State private var viewModel: CinemaMapViewModel
    private let findRoute: CinemaRouteFinder
    private let placement: CinemaMapPlacement

    @State private var cameraPosition = MapCameraPosition.region(wroclawMapRegion)
    @State private var openedCinemas: [Cinema] = []
    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: CinemaMapViewModel,
        findRoute: @escaping CinemaRouteFinder,
        placement: CinemaMapPlacement
    ) {
        _viewModel = State(initialValue: viewModel)
        self.findRoute = findRoute
        self.placement = placement
    }

    var body: some View {
        NavigationStack(path: $openedCinemas) {
            VStack(spacing: 0) {
                map
                locationNote
                cinemaList
            }
            .navigationTitle("Cinemas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneButton }
            .navigationDestination(for: Cinema.self, destination: cinemaDetail)
            .task { await viewModel.locateUserIfNeeded() }
        }
    }

    private var map: some View {
        Map(position: $cameraPosition, selection: mapSelection) {
            UserAnnotation()
            ForEach(viewModel.cinemas) { cinema in
                cinemaMarker(cinema)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange { context in viewModel.visibleRegion = context.region }
        .containerRelativeFrame(.vertical) { height, _ in height * mapHeightFraction }
    }

    private func cinemaMarker(_ cinema: Cinema) -> some MapContent {
        let coordinate = cinemaCoordinate(cinema)
        return Marker(cinema.name, systemImage: symbolNameCinema, coordinate: coordinate)
            .tag(cinema.id)
    }

    /// The map uses nil for no selection, the view model `noCinemaSelected`.
    private var mapSelection: Binding<String?> {
        return Binding(get: selectedCinemaIdForMap, set: selectCinemaFromMap)
    }

    private func selectedCinemaIdForMap() -> String? {
        if viewModel.selectedCinemaId == noCinemaSelected {
            return nil
        }
        return viewModel.selectedCinemaId
    }

    private func selectCinemaFromMap(_ cinemaId: String?) {
        viewModel.selectedCinemaId = cinemaId ?? noCinemaSelected
    }

    @ViewBuilder
    private var locationNote: some View {
        if viewModel.isLocationUnavailable {
            Label(
                "Turn on location to see distances and routes.", systemImage: symbolNameLocationOff
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacingSmall)
            .background(.quaternary)
        }
    }

    private var cinemaList: some View {
        ScrollViewReader { proxy in
            List(viewModel.cinemas) { cinema in
                cinemaRow(cinema)
            }
            .listStyle(.plain)
            .onChange(of: viewModel.selectedCinemaId) { _, cinemaId in
                scrollToCinema(proxy, cinemaId: cinemaId)
            }
        }
    }

    private func cinemaRow(_ cinema: Cinema) -> some View {
        HStack(spacing: spacingMedium) {
            Button {
                selectCinemaFromList(cinema)
            } label: {
                CinemaRow(cinema: cinema)
            }
            .buttonStyle(.plain)
            Button {
                openedCinemas.append(cinema)
            } label: {
                Label("Details", systemImage: symbolNameDetails).labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
        .listRowBackground(rowBackground(cinema))
    }

    private func rowBackground(_ cinema: Cinema) -> Color {
        if viewModel.selectedCinemaId == cinema.id {
            return Color.accentColor.opacity(selectedRowOpacity)
        }
        return Color.clear
    }

    /// A row selects its cinema and moves the map to it, keeping the zoom.
    private func selectCinemaFromList(_ cinema: Cinema) {
        viewModel.toggleCinema(cinema)
        if viewModel.selectedCinemaId != cinema.id {
            return
        }
        let movedRegion = regionMoved(viewModel.visibleRegion, to: cinemaCoordinate(cinema))
        withAnimation {
            cameraPosition = .region(movedRegion)
        }
    }

    private func scrollToCinema(_ proxy: ScrollViewProxy, cinemaId: String) {
        if !containsCinema(viewModel.cinemas, cinemaId: cinemaId) {
            return
        }
        withAnimation {
            proxy.scrollTo(cinemaId)
        }
    }

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        if placement == .sheet {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func cinemaDetail(_ cinema: Cinema) -> some View {
        let detailViewModel = CinemaDetailViewModel(
            cinema: cinema,
            userLocation: viewModel.userLocation,
            findRoute: findRoute
        )
        return CinemaDetailView(viewModel: detailViewModel)
    }
}

/// Name and address, the distance on the right.
private struct CinemaRow: View {
    let cinema: Cinema

    var body: some View {
        HStack(spacing: spacingMedium) {
            VStack(alignment: .leading, spacing: spacingExtraSmall) {
                Text(cinema.name).font(.headline)
                Text(cinema.address).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(formattedDistance(cinema.distanceInMeters))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// Builds the map like the Cinemas tab, for the tab and for the sheet of a movie.
func makeCinemaMapView(placement: CinemaMapPlacement) -> CinemaMapView {
    let viewModel = CinemaMapViewModel(
        cinemas: wroclawCinemas,
        findUserLocation: findUserLocation,
        lastKnownLocation: lastKnownUserLocation
    )
    return CinemaMapView(viewModel: viewModel, findRoute: findMapKitRoute, placement: placement)
}

#Preview {
    let viewModel = CinemaMapViewModel(
        cinemas: wroclawCinemas,
        findUserLocation: { UserLocation(latitude: 51.0983, longitude: 17.0368, isKnown: true) }
    )
    CinemaMapView(viewModel: viewModel, findRoute: { _, _, _ in noRoute }, placement: .tab)
}
