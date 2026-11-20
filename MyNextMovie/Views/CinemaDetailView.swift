import MapKit
import SwiftUI

private let detailMapHeight: CGFloat = 260
private let lookAroundHeight: CGFloat = 200
private let routeLineWidth: CGFloat = 5

/// One cinema: the map with the way there, the address, links and Look Around.
struct CinemaDetailView: View {
    @State private var viewModel: CinemaDetailViewModel
    @State private var cameraPosition = MapCameraPosition.automatic
    @State private var lookAroundScene: MKLookAroundScene?

    init(viewModel: CinemaDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section { map }
            addressSection
            wayThereSection
            linksSection
            lookAroundSection
        }
        .navigationTitle(viewModel.cinema.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.travelMode) { await viewModel.loadRoute() }
        .task { lookAroundScene = await findLookAroundScene(viewModel.cinema) }
    }

    /// The camera frames the pin and the route.
    private var map: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            Marker(
                viewModel.cinema.name,
                systemImage: symbolNameCinema,
                coordinate: cinemaCoordinate(viewModel.cinema)
            )
            if viewModel.routeState == .loaded {
                MapPolyline(viewModel.route.line).stroke(.blue, lineWidth: routeLineWidth)
            }
        }
        .frame(height: detailMapHeight)
        .listRowInsets(EdgeInsets())
        .onChange(of: viewModel.routeState) { cameraPosition = .automatic }
    }

    private var addressSection: some View {
        Section {
            Text(viewModel.cinema.address)
            distanceRow
        }
    }

    /// The distance in a straight line, known only when the location is known.
    @ViewBuilder
    private var distanceRow: some View {
        let distance = viewModel.cinema.distanceInMeters
        if distance >= 0 {
            LabeledContent("Distance", value: formattedDistance(distance))
        }
    }

    private var wayThereSection: some View {
        Section("Way There") {
            Picker("Travel Mode", selection: $viewModel.travelMode) {
                Text("Walk").tag(TravelMode.walking)
                Text("Drive").tag(TravelMode.driving)
            }
            .pickerStyle(.segmented)
            routeStatus
        }
    }

    @ViewBuilder
    private var routeStatus: some View {
        if !viewModel.canFindRoute {
            Label("Turn on location to see the way.", systemImage: symbolNameLocationOff)
                .foregroundStyle(.secondary)
        } else if viewModel.routeState == .loaded {
            Label(routeSummary(viewModel.route), systemImage: travelModeSymbolName)
        } else if viewModel.routeState == .failed {
            Label(viewModel.errorMessage, systemImage: symbolNameError)
                .foregroundStyle(.secondary)
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private var travelModeSymbolName: String {
        switch viewModel.travelMode {
        case .walking:
            return symbolNameWalking
        case .driving:
            return symbolNameDriving
        }
    }

    private var linksSection: some View {
        Section {
            Button {
                openCinemaInMaps(viewModel.cinema, travelMode: viewModel.travelMode)
            } label: {
                Label("Directions in Maps", systemImage: symbolNameDirections)
            }
            phoneLink
            websiteLink
        }
    }

    @ViewBuilder
    private var phoneLink: some View {
        if let phoneAddress = phoneURL(viewModel.cinema) {
            Link(destination: phoneAddress) {
                Label(viewModel.cinema.phoneNumber, systemImage: symbolNamePhone)
            }
        }
    }

    @ViewBuilder
    private var websiteLink: some View {
        if let websiteAddress = websiteURL(viewModel.cinema) {
            Link(destination: websiteAddress) {
                Label("Website", systemImage: symbolNameWebsite)
            }
        }
    }

    /// Shown only when Apple has street photos at the cinema.
    @ViewBuilder
    private var lookAroundSection: some View {
        if let lookAroundScene {
            Section("Look Around") { lookAroundPreview(lookAroundScene) }
        }
    }

    private func lookAroundPreview(_ scene: MKLookAroundScene) -> some View {
        return LookAroundPreview(initialScene: scene)
            .frame(height: lookAroundHeight)
            .listRowInsets(EdgeInsets())
    }
}

#Preview {
    let viewModel = CinemaDetailViewModel(
        cinema: wroclawCinemas[0],
        userLocation: UserLocation(latitude: 51.0983, longitude: 17.0368, isKnown: true),
        findRoute: findMapKitRoute
    )
    NavigationStack {
        CinemaDetailView(viewModel: viewModel)
    }
}
