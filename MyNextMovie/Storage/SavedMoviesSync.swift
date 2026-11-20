import Foundation
import SwiftData

// Keeps the saved movies on this device and in the account the same.
// SwiftData is what the screens show, Supabase is the copy in the cloud.
// While a request is on its way the user can save or remove a movie, so after every `await`
// the database is read again and only movie ids are carried across an `await`.

/// 1. Movies removed here are removed from the account.
/// 2. Movies of the account come here, movies removed on another device go away here.
/// 3. New movies from here go to the account.
/// Throws when a request fails. The changes that were not sent stay marked for the next sync.
func syncSavedMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    try await sendRemovals(context, cloud: cloud)
    try await mergeAccountMovies(context, cloud: cloud)
    try await sendNewMovies(context, cloud: cloud)
}

func cloudMovieFromSaved(_ savedMovie: SavedMovie) -> CloudSavedMovie {
    return CloudSavedMovie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds,
        savedAt: savedMovie.savedAt
    )
}

func movieFromCloud(_ cloudMovie: CloudSavedMovie) -> Movie {
    return Movie(
        id: cloudMovie.id,
        title: cloudMovie.title,
        overview: cloudMovie.overview,
        releaseDate: cloudMovie.releaseDate,
        posterPath: cloudMovie.posterPath,
        voteAverage: cloudMovie.voteAverage,
        genreIds: cloudMovie.genreIds
    )
}

/// Step 1: every `RemovedSavedMovie` is removed from the account, then the mark goes away.
private func sendRemovals(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    var removedMovieIds: [Int] = []
    for removalMark in fetchRemovalMarks(context) {
        removedMovieIds.append(removalMark.movieId)
    }
    for movieId in removedMovieIds {
        try await cloud.removeMovie(movieId)
        deleteRemovalMarks(context, movieId: movieId)
    }
}

/// Step 2: the account is the pattern for this device.
private func mergeAccountMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    let cloudMovies = try await cloud.fetchMovies()
    var accountMovieIds: [Int] = []
    for cloudMovie in cloudMovies {
        accountMovieIds.append(cloudMovie.id)
    }
    removeMoviesRemovedElsewhere(context, accountMovieIds: accountMovieIds)
    for cloudMovie in cloudMovies {
        addAccountMovie(context, cloudMovie)
    }
}

/// A movie the account had, but has no more, was removed on another device.
private func removeMoviesRemovedElsewhere(_ context: ModelContext, accountMovieIds: [Int]) {
    let savedMovies = (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? []
    for savedMovie in savedMovies {
        if savedMovie.isInCloud && !accountMovieIds.contains(savedMovie.movieId) {
            context.delete(savedMovie)
        }
    }
}

/// A movie of the account comes here, unless it was just removed here.
private func addAccountMovie(_ context: ModelContext, _ cloudMovie: CloudSavedMovie) {
    if !fetchRemovalMarks(context, movieId: cloudMovie.id).isEmpty {
        return
    }
    let savedCopies = fetchSavedMovies(context, movieId: cloudMovie.id)
    if savedCopies.isEmpty {
        let movie = movieFromCloud(cloudMovie)
        context.insert(SavedMovie(movie: movie, savedAt: cloudMovie.savedAt, isInCloud: true))
    }
    for savedCopy in savedCopies {
        savedCopy.isInCloud = true
    }
}

/// Step 3: every movie the account does not have yet goes in one upload.
private func sendNewMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in savedMovie.isInCloud == false }
    )
    let newMovies = (try? context.fetch(descriptor)) ?? []
    if newMovies.isEmpty {
        return
    }
    var cloudMovies: [CloudSavedMovie] = []
    var sentMovieIds: [Int] = []
    for newMovie in newMovies {
        cloudMovies.append(cloudMovieFromSaved(newMovie))
        sentMovieIds.append(newMovie.movieId)
    }
    try await cloud.uploadMovies(cloudMovies)
    for movieId in sentMovieIds {
        markMovieSent(context, movieId: movieId)
    }
}

/// After the upload the account has the movie. A movie removed during the upload
/// gets a `RemovedSavedMovie`, so it goes away from the account too.
private func markMovieSent(_ context: ModelContext, movieId: Int) {
    let savedCopies = fetchSavedMovies(context, movieId: movieId)
    if savedCopies.isEmpty {
        markMovieRemoved(context, movieId: movieId)
    }
    for savedCopy in savedCopies {
        savedCopy.isInCloud = true
    }
}
