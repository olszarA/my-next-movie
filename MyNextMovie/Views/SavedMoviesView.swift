import SwiftData
import SwiftUI

/// The Saved tab: movies saved to watch later, the newest first.
struct SavedMoviesView: View {
    @Query(sort: \SavedMovie.savedAt, order: .reverse) private var savedMovies: [SavedMovie]
    private let loadDetails: MovieDetailsLoader

    init(loadDetails: @escaping MovieDetailsLoader) {
        self.loadDetails = loadDetails
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Saved")
                .navigationDestination(for: Movie.self, destination: movieDetail)
        }
    }

    @ViewBuilder
    private var content: some View {
        if savedMovies.isEmpty {
            ContentUnavailableView(
                "No saved movies",
                systemImage: symbolNameSaved,
                description: Text("Tap the bookmark on a movie's details to watch it later.")
            )
        } else {
            MovieGrid(title: "Watch Later", movies: moviesFromSaved(savedMovies))
        }
    }

    private func movieDetail(_ movie: Movie) -> some View {
        MovieDetailView(movie: movie, loadDetails: loadDetails)
    }
}

/// Bookmark on the bar of the details: saves the movie or removes it from Saved.
struct SaveMovieButton: View {
    let movie: Movie

    @Environment(\.modelContext) private var modelContext
    /// Only the saved copy of this movie, an empty array when it is not saved.
    @Query private var savedCopies: [SavedMovie]

    init(movie: Movie) {
        self.movie = movie
        let movieId = movie.id
        _savedCopies = Query(filter: #Predicate { savedMovie in savedMovie.movieId == movieId })
    }

    var body: some View {
        Button {
            toggleSavedMovie(modelContext, movie, now: Date.now)
        } label: {
            Label(isSaved ? "Remove from Saved" : "Save", systemImage: bookmarkSymbolName)
        }
    }

    private var isSaved: Bool {
        return !savedCopies.isEmpty
    }

    private var bookmarkSymbolName: String {
        return isSaved ? symbolNameSavedFilled : symbolNameSaved
    }
}

#Preview {
    SavedMoviesView(loadDetails: fetchMovieDetails)
        .modelContainer(for: storedModelTypes, inMemory: true)
}
