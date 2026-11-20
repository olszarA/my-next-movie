import SwiftUI

@main
struct MyNextMovieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                movieList
            }
            Tab("Search", systemImage: symbolNameSearch, role: .search) {
                search
            }
        }
    }

    private var movieList: some View {
        let viewModel = MovieListViewModel(loadMovies: fetchPopularMovies)
        return MovieListView(viewModel: viewModel, loadDetails: fetchMovieDetails)
    }

    private var search: some View {
        let viewModel = SearchViewModel(searchMovies: searchTMDBMovies)
        return SearchView(viewModel: viewModel, loadDetails: fetchMovieDetails)
    }
}
