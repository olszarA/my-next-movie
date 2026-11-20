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

/// Wraps the functions that need the SwiftData context into plain `MovieLoader`
/// and `MovieDetailsLoader`, so the view models do not know about the database.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                movieList
            }
            Tab("Saved", systemImage: symbolNameSaved) {
                SavedMoviesView(loadDetails: loadDetailsWithCache)
            }
            Tab("Search", systemImage: symbolNameSearch, role: .search) {
                search
            }
        }
    }

    private var movieList: some View {
        let viewModel = MovieListViewModel(loadMovies: loadPopularMoviesWithCache)
        return MovieListView(viewModel: viewModel, loadDetails: loadDetailsWithCache)
    }

    private var search: some View {
        let viewModel = SearchViewModel(searchMovies: searchTMDBMovies)
        return SearchView(viewModel: viewModel, loadDetails: loadDetailsWithCache)
    }

    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}
