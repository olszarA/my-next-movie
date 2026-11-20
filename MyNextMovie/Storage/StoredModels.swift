import Foundation
import SwiftData

/// A movie saved to watch later. It keeps every field of `Movie`,
/// so the Saved tab works without the network.
@Model
final class SavedMovie {
    @Attribute(.unique) var movieId: Int
    var title: String
    var overview: String
    var releaseDate: String
    var posterPath: String?
    var voteAverage: Double
    var genreIds: [Int]
    var savedAt: Date
    /// Whether the account in Supabase already has the movie. Used from lab 5.
    var isInCloud: Bool = false

    init(movie: Movie, savedAt: Date) {
        self.movieId = movie.id
        self.title = movie.title
        self.overview = movie.overview
        self.releaseDate = movie.releaseDate
        self.posterPath = movie.posterPath
        self.voteAverage = movie.voteAverage
        self.genreIds = movie.genreIds
        self.savedAt = savedAt
        self.isInCloud = false
    }
}

/// One search the user sent with the Search key.
@Model
final class SearchHistoryEntry {
    @Attribute(.unique) var query: String
    var searchedAt: Date

    init(query: String, searchedAt: Date) {
        self.query = query
        self.searchedAt = searchedAt
    }
}

/// The last raw JSON answer of TMDB for one request, shown when the network is down.
@Model
final class CachedResponse {
    @Attribute(.unique) var key: String
    var data: Data
    var fetchedAt: Date

    init(key: String, data: Data, fetchedAt: Date) {
        self.key = key
        self.data = data
        self.fetchedAt = fetchedAt
    }
}

/// Every SwiftData model of the app, for `.modelContainer(for:)`.
let storedModelTypes: [any PersistentModel.Type] = [
    SavedMovie.self,
    SearchHistoryEntry.self,
    CachedResponse.self,
]
