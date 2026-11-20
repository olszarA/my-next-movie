import SwiftData
import SwiftUI

@main
struct MyNextMovieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: storedModelTypes)
    }
}

/// Wraps the functions that need the SwiftData context into plain function types,
/// so the view models do not know about the database.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AppTabs(
            account: makeAccountViewModel(),
            loadPopularMovies: loadPopularMoviesWithCache,
            loadDetails: loadDetailsWithCache
        )
    }

    private func makeAccountViewModel() -> AccountViewModel {
        let context = modelContext
        let cloud = supabaseSavedMoviesCloud
        let viewModel = AccountViewModel(
            account: supabaseAccountService,
            syncSavedMovies: { try await syncSavedMovies(context, cloud: cloud) },
            clearSavedMovies: { clearSavedMovies(context) }
        )
        #if DEBUG
            viewModel.email = testAccountEmail
            viewModel.password = testAccountPassword
        #endif
        return viewModel
    }

    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}

/// The tabs for a signed-in user, the sign in screen otherwise.
/// Syncs the saved movies at the start, after coming back to the app
/// and after a movie is saved or removed.
private struct AppTabs: View {
    @State private var account: AccountViewModel
    private let loadPopularMovies: MovieLoader
    private let loadDetails: MovieDetailsLoader

    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<SavedMovie> { savedMovie in savedMovie.isInCloud == false })
    private var moviesNotInCloud: [SavedMovie]
    @Query private var removedMovies: [RemovedSavedMovie]

    init(
        account: AccountViewModel,
        loadPopularMovies: @escaping MovieLoader,
        loadDetails: @escaping MovieDetailsLoader
    ) {
        _account = State(initialValue: account)
        self.loadPopularMovies = loadPopularMovies
        self.loadDetails = loadDetails
    }

    @ViewBuilder
    var body: some View {
        if account.isSignedIn {
            tabs
        } else {
            SignInView(viewModel: account)
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) { movieList }
            Tab("Saved", systemImage: symbolNameSaved) {
                SavedMoviesView(loadDetails: loadDetails)
            }
            Tab("Account", systemImage: symbolNameAccount) {
                AccountView(viewModel: account)
            }
            Tab("Search", systemImage: symbolNameSearch, role: .search) { search }
        }
        .task { await account.syncSavedMovies() }
        .onChange(of: scenePhase, syncAfterComingBack)
        .onChange(of: unsentChangeCount, syncAfterNewChange)
    }

    private var movieList: some View {
        let viewModel = MovieListViewModel(loadMovies: loadPopularMovies)
        return MovieListView(viewModel: viewModel, loadDetails: loadDetails)
    }

    private var search: some View {
        let viewModel = SearchViewModel(searchMovies: searchTMDBMovies)
        return SearchView(viewModel: viewModel, loadDetails: loadDetails)
    }

    /// Movies saved and removed here that the account does not know about yet.
    private var unsentChangeCount: Int {
        return moviesNotInCloud.count + removedMovies.count
    }

    private func syncAfterComingBack(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        if newPhase == .active {
            Task { await account.syncSavedMovies() }
        }
    }

    /// A drop in the count is the result of a sync and needs no other one.
    private func syncAfterNewChange(_ oldCount: Int, _ newCount: Int) {
        if newCount > oldCount {
            Task { await account.syncSavedMovies() }
        }
    }
}
