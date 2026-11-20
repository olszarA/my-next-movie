import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

/// An empty database in memory, a new one for every test.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Schema(storedModelTypes), configurations: [configuration])
}

/// The tests start at 1 January 1970 and count minutes from there.
private let testStartDate = Date(timeIntervalSince1970: 0)
private let secondsPerMinute: TimeInterval = 60

private func minutesAfterStart(_ minutes: Int) -> Date {
    return testStartDate.addingTimeInterval(secondsPerMinute * TimeInterval(minutes))
}

@MainActor
struct SavedMovieTests {
    @Test func toggleSavesThenRemoves() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let matrix = testMovies[0]

        toggleSavedMovie(context, matrix, now: minutesAfterStart(1))
        #expect(isMovieSaved(context, movieId: matrix.id))

        toggleSavedMovie(context, matrix, now: minutesAfterStart(2))
        #expect(!isMovieSaved(context, movieId: matrix.id))
    }

    @Test func savedCopyKeepsEveryField() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let matrix = testMovies[0]

        toggleSavedMovie(context, matrix, now: minutesAfterStart(1))

        let savedMovies = try context.fetch(FetchDescriptor<SavedMovie>())
        #expect(moviesFromSaved(savedMovies) == [matrix])
    }
}

@MainActor
struct SearchHistoryTests {
    @Test func newestSearchComesFirst() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minutesAfterStart(1))
        recordSearch(context, query: "alien", now: minutesAfterStart(2))

        #expect(queriesOf(recentSearches(context)) == ["alien", "matrix"])
    }

    @Test func repeatedSearchMovesToTop() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minutesAfterStart(1))
        recordSearch(context, query: "alien", now: minutesAfterStart(2))
        recordSearch(context, query: "matrix", now: minutesAfterStart(3))

        #expect(queriesOf(recentSearches(context)) == ["matrix", "alien"])
    }

    @Test func emptyAndSpacesAreNotRecorded() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "", now: minutesAfterStart(1))
        recordSearch(context, query: "   ", now: minutesAfterStart(2))
        recordSearch(context, query: "  dune  ", now: minutesAfterStart(3))

        #expect(queriesOf(recentSearches(context)) == ["dune"])
    }

    @Test func keepsOnlyRecentSearches() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let searchCount = 13

        for searchNumber in 1...searchCount {
            recordSearch(
                context, query: "movie \(searchNumber)", now: minutesAfterStart(searchNumber))
        }

        let entryCount = try context.fetchCount(FetchDescriptor<SearchHistoryEntry>())
        #expect(entryCount == maxSearchHistoryCount)
        #expect(recentSearches(context).first?.query == "movie \(searchCount)")
    }

    @Test func clearRemovesEverything() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        recordSearch(context, query: "matrix", now: minutesAfterStart(1))
        recordSearch(context, query: "alien", now: minutesAfterStart(2))

        clearSearchHistory(context)

        #expect(recentSearches(context).isEmpty)
    }
}

@MainActor
struct ResponseCacheTests {
    private let cacheKey = "popular"
    private let oldAnswer = Data("old".utf8)
    private let newAnswer = Data("new".utf8)

    @Test func missingKeyGivesEmptyData() throws {
        let container = try makeTestContainer()

        #expect(cachedResponseData(container.mainContext, key: cacheKey).isEmpty)
    }

    @Test func storingAgainReplacesData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        storeCachedResponse(context, key: cacheKey, data: oldAnswer, now: minutesAfterStart(1))
        storeCachedResponse(context, key: cacheKey, data: newAnswer, now: minutesAfterStart(2))

        #expect(cachedResponseData(context, key: cacheKey) == newAnswer)
        #expect(try context.fetchCount(FetchDescriptor<CachedResponse>()) == 1)
    }

    @Test func freshAnswerIsReturnedAndCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let answer = newAnswer

        let data = try await fetchWithCacheFallback(context, key: cacheKey) { answer }

        #expect(data == newAnswer)
        #expect(cachedResponseData(context, key: cacheKey) == newAnswer)
    }

    @Test func cachedAnswerIsReturnedWhenOffline() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        storeCachedResponse(context, key: cacheKey, data: oldAnswer, now: minutesAfterStart(1))

        let data = try await fetchWithCacheFallback(context, key: cacheKey) {
            throw NoConnection()
        }

        #expect(data == oldAnswer)
    }

    @Test func errorIsRethrownWhenNothingCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        await #expect(throws: NoConnection.self) {
            try await fetchWithCacheFallback(context, key: cacheKey) {
                throw NoConnection()
            }
        }
    }
}

@MainActor
private func queriesOf(_ entries: [SearchHistoryEntry]) -> [String] {
    var queries: [String] = []
    for entry in entries {
        queries.append(entry.query)
    }
    return queries
}
