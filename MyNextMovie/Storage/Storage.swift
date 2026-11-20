import Foundation
import SwiftData

// Reading and writing the SwiftData database. Every function gets the context as a parameter,
// and the functions that write a date get the current one as `now`,
// so the tests can pass a database in memory and a fixed date.

let maxSearchHistoryCount = 10

// MARK: - Saved movies

/// Saved copies of the movie: an empty array or one copy.
func fetchSavedMovies(_ context: ModelContext, movieId: Int) -> [SavedMovie] {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in savedMovie.movieId == movieId }
    )
    return (try? context.fetch(descriptor)) ?? []
}

func isMovieSaved(_ context: ModelContext, movieId: Int) -> Bool {
    return !fetchSavedMovies(context, movieId: movieId).isEmpty
}

/// Saves the movie, or removes it when it is already saved. Removing a movie the account has
/// leaves a `RemovedSavedMovie`, so the next sync removes it from the account too.
func toggleSavedMovie(_ context: ModelContext, _ movie: Movie, now: Date) {
    let savedCopies = fetchSavedMovies(context, movieId: movie.id)
    if savedCopies.isEmpty {
        // Saved again before the sync: the account still has it, so the mark goes away.
        deleteRemovalMarks(context, movieId: movie.id)
        context.insert(SavedMovie(movie: movie, savedAt: now, isInCloud: false))
        return
    }
    for savedCopy in savedCopies {
        if savedCopy.isInCloud {
            markMovieRemoved(context, movieId: savedCopy.movieId)
        }
        context.delete(savedCopy)
    }
}

/// For signing out: removes every saved movie and every mark from this device.
/// The account keeps its movies.
func clearSavedMovies(_ context: ModelContext) {
    let savedMovies = (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? []
    for savedMovie in savedMovies {
        context.delete(savedMovie)
    }
    for removalMark in fetchRemovalMarks(context) {
        context.delete(removalMark)
    }
}

// MARK: - Removal marks

func fetchRemovalMarks(_ context: ModelContext) -> [RemovedSavedMovie] {
    return (try? context.fetch(FetchDescriptor<RemovedSavedMovie>())) ?? []
}

func markMovieRemoved(_ context: ModelContext, movieId: Int) {
    if fetchRemovalMarks(context, movieId: movieId).isEmpty {
        context.insert(RemovedSavedMovie(movieId: movieId))
    }
}

func deleteRemovalMarks(_ context: ModelContext, movieId: Int) {
    for removalMark in fetchRemovalMarks(context, movieId: movieId) {
        context.delete(removalMark)
    }
}

func fetchRemovalMarks(_ context: ModelContext, movieId: Int) -> [RemovedSavedMovie] {
    let descriptor = FetchDescriptor<RemovedSavedMovie>(
        predicate: #Predicate { removalMark in removalMark.movieId == movieId }
    )
    return (try? context.fetch(descriptor)) ?? []
}

func movieFromSaved(_ savedMovie: SavedMovie) -> Movie {
    return Movie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds
    )
}

func moviesFromSaved(_ savedMovies: [SavedMovie]) -> [Movie] {
    var movies: [Movie] = []
    for savedMovie in savedMovies {
        movies.append(movieFromSaved(savedMovie))
    }
    return movies
}

// MARK: - Search history

/// Remembers the search. A repeated search gets the new date and moves to the top.
func recordSearch(_ context: ModelContext, query: String, now: Date) {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    if trimmedQuery.isEmpty {
        return
    }
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        predicate: #Predicate { entry in entry.query == trimmedQuery }
    )
    let existingEntries = (try? context.fetch(descriptor)) ?? []
    if existingEntries.isEmpty {
        context.insert(SearchHistoryEntry(query: trimmedQuery, searchedAt: now))
    }
    for existingEntry in existingEntries {
        existingEntry.searchedAt = now
    }
    removeOldSearches(context)
}

/// Newest first, at most `maxSearchHistoryCount`.
func recentSearches(_ context: ModelContext) -> [SearchHistoryEntry] {
    let allEntries = searchHistoryNewestFirst(context)
    var recentEntries: [SearchHistoryEntry] = []
    for entry in allEntries {
        if recentEntries.count == maxSearchHistoryCount {
            break
        }
        recentEntries.append(entry)
    }
    return recentEntries
}

func clearSearchHistory(_ context: ModelContext) {
    for entry in searchHistoryNewestFirst(context) {
        context.delete(entry)
    }
}

/// Keeps `maxSearchHistoryCount` newest entries and removes the older ones.
/// `fetchOffset` skips entries that are not on disk yet, so the entries are counted here.
private func removeOldSearches(_ context: ModelContext) {
    var keptCount = 0
    for entry in searchHistoryNewestFirst(context) {
        if keptCount < maxSearchHistoryCount {
            keptCount += 1
            continue
        }
        context.delete(entry)
    }
}

private func searchHistoryNewestFirst(_ context: ModelContext) -> [SearchHistoryEntry] {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
}

// MARK: - Cached TMDB answers

/// Saves the JSON under the key. One key is one answer, a new one replaces the old one.
func storeCachedResponse(_ context: ModelContext, key: String, data: Data, now: Date) {
    let cachedResponses = fetchCachedResponses(context, key: key)
    if cachedResponses.isEmpty {
        context.insert(CachedResponse(key: key, data: data, fetchedAt: now))
    }
    for cachedResponse in cachedResponses {
        cachedResponse.data = data
        cachedResponse.fetchedAt = now
    }
}

/// The saved JSON, empty `Data()` when there is none.
func cachedResponseData(_ context: ModelContext, key: String) -> Data {
    let cachedResponses = fetchCachedResponses(context, key: key)
    if cachedResponses.isEmpty {
        return Data()
    }
    return cachedResponses[0].data
}

/// `fetch()` first, its answer is saved and returned. When `fetch()` throws,
/// the saved answer is returned instead. Without one the same error is thrown on.
func fetchWithCacheFallback(
    _ context: ModelContext,
    key: String,
    fetch: () async throws -> Data
) async throws -> Data {
    do {
        let freshData = try await fetch()
        storeCachedResponse(context, key: key, data: freshData, now: Date.now)
        return freshData
    } catch {
        let cachedData = cachedResponseData(context, key: key)
        if cachedData.isEmpty {
            throw error
        }
        return cachedData
    }
}

private func fetchCachedResponses(_ context: ModelContext, key: String) -> [CachedResponse] {
    let descriptor = FetchDescriptor<CachedResponse>(
        predicate: #Predicate { cachedResponse in cachedResponse.key == key }
    )
    return (try? context.fetch(descriptor)) ?? []
}
