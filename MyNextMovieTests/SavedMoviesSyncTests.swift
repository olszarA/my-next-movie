import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

private let firstSaveDate = Date(timeIntervalSince1970: 60)
private let secondSaveDate = Date(timeIntervalSince1970: 120)
private let thirdSaveDate = Date(timeIntervalSince1970: 180)

/// The `saved_movies` table of one account. A class, so the closures and the test
/// see the same rows.
@MainActor
private final class TestCloud {
    var movies: [CloudSavedMovie] = []
    var isOffline = false
    var uploadCount = 0

    func movieIds() -> [Int] {
        var ids: [Int] = []
        for movie in movies {
            ids.append(movie.id)
        }
        return ids
    }

    func makeCloud() -> SavedMoviesCloud {
        return SavedMoviesCloud(
            fetchMovies: {
                try self.checkConnection()
                return self.movies
            },
            uploadMovies: { cloudMovies in
                try self.checkConnection()
                self.upload(cloudMovies)
            },
            removeMovie: { movieId in
                try self.checkConnection()
                self.remove(movieId: movieId)
            }
        )
    }

    private func checkConnection() throws {
        if isOffline {
            throw NoConnection()
        }
    }

    /// Like `upsert` with `ignoreDuplicates`: a movie the account has stays as it is.
    private func upload(_ cloudMovies: [CloudSavedMovie]) {
        uploadCount += 1
        for cloudMovie in cloudMovies {
            if !movieIds().contains(cloudMovie.id) {
                movies.append(cloudMovie)
            }
        }
    }

    private func remove(movieId: Int) {
        var keptMovies: [CloudSavedMovie] = []
        for movie in movies {
            if movie.id != movieId {
                keptMovies.append(movie)
            }
        }
        movies = keptMovies
    }
}

@MainActor
private func cloudMovie(_ movie: Movie, savedAt: Date) -> CloudSavedMovie {
    let savedMovie = SavedMovie(movie: movie, savedAt: savedAt, isInCloud: true)
    return cloudMovieFromSaved(savedMovie)
}

@MainActor
private func savedMovieIds(_ context: ModelContext) -> [Int] {
    let savedMovies = (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? []
    var ids: [Int] = []
    for savedMovie in savedMovies {
        ids.append(savedMovie.movieId)
    }
    return ids.sorted()
}

@MainActor
struct SavedMoviesSyncTests {
    private var matrix: Movie { return testMovies[0] }
    private var inception: Movie { return testMovies[1] }

    @Test func movieSavedOnDeviceGoesToAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, matrix, now: firstSaveDate)

        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.movies == [cloudMovie(matrix, savedAt: firstSaveDate)])
        let savedCopy = try #require(fetchSavedMovies(context, movieId: matrix.id).first)
        #expect(savedCopy.isInCloud)
    }

    @Test func movieIsSentOnlyOnce() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, matrix, now: firstSaveDate)

        try await syncSavedMovies(context, cloud: testCloud.makeCloud())
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.uploadCount == 1)
        #expect(testCloud.movies.count == 1)
    }

    @Test func movieFromAccountComesToDevice() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        testCloud.movies = [cloudMovie(matrix, savedAt: firstSaveDate)]

        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        let savedCopy = try #require(fetchSavedMovies(context, movieId: matrix.id).first)
        #expect(savedCopy.isInCloud)
        #expect(savedCopy.savedAt == firstSaveDate)
        #expect(movieFromSaved(savedCopy) == matrix)
    }

    @Test func deviceAndAccountListsAreMerged() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        testCloud.movies = [cloudMovie(matrix, savedAt: firstSaveDate)]
        toggleSavedMovie(context, inception, now: secondSaveDate)

        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        let bothIds = [matrix.id, inception.id].sorted()
        #expect(savedMovieIds(context) == bothIds)
        #expect(testCloud.movieIds().sorted() == bothIds)
    }

    @Test func movieRemovedOnDeviceIsRemovedFromAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, matrix, now: firstSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        toggleSavedMovie(context, matrix, now: secondSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.movies.isEmpty)
        #expect(savedMovieIds(context).isEmpty)
        #expect(fetchRemovalMarks(context).isEmpty)
    }

    @Test func movieRemovedOnAnotherDeviceIsRemovedHere() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        testCloud.movies = [cloudMovie(matrix, savedAt: firstSaveDate)]
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        testCloud.movies = []
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(savedMovieIds(context).isEmpty)
    }

    @Test func changesMadeOfflineAreSentWithTheNextSync() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, matrix, now: firstSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        testCloud.isOffline = true
        toggleSavedMovie(context, matrix, now: secondSaveDate)
        toggleSavedMovie(context, inception, now: secondSaveDate)
        await #expect(throws: NoConnection.self) {
            try await syncSavedMovies(context, cloud: testCloud.makeCloud())
        }
        #expect(testCloud.movieIds() == [matrix.id])

        testCloud.isOffline = false
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.movieIds() == [inception.id])
        #expect(savedMovieIds(context) == [inception.id])
    }

    @Test func movieRemovedAndSavedAgainOfflineStays() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, matrix, now: firstSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        toggleSavedMovie(context, matrix, now: secondSaveDate)
        toggleSavedMovie(context, matrix, now: thirdSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.movieIds() == [matrix.id])
        #expect(fetchRemovalMarks(context).isEmpty)
        let savedCopy = try #require(fetchSavedMovies(context, movieId: matrix.id).first)
        #expect(savedCopy.savedAt == thirdSaveDate)
        #expect(savedCopy.isInCloud)
    }
}

@MainActor
struct CloudSavedMovieTests {
    @Test func encodesColumnNamesInSnakeCase() throws {
        let row = cloudMovie(testMovies[0], savedAt: firstSaveDate)

        let json = try #require(String(data: JSONEncoder().encode(row), encoding: .utf8))

        let columnNames = ["release_date", "poster_path", "vote_average", "genre_ids", "saved_at"]
        for columnName in columnNames {
            #expect(json.contains("\"\(columnName)\""))
        }
        #expect(!json.contains("releaseDate"))
    }

    @Test func cloudCopyKeepsEveryMovieField() {
        for movie in testMovies {
            let savedMovie = SavedMovie(movie: movie, savedAt: firstSaveDate, isInCloud: false)

            #expect(movieFromCloud(cloudMovieFromSaved(savedMovie)) == movie)
        }
    }
}
