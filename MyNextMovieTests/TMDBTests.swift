import Foundation
import Testing

@testable import MyNextMovie

/// A shortened answer of `/3/movie/popular`. The second movie has no poster.
private let popularMoviesJSON = """
    {
      "page": 1,
      "results": [
        {
          "id": 603,
          "title": "The Matrix",
          "overview": "A hacker learns that the world is a simulation.",
          "release_date": "1999-03-31",
          "poster_path": "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
          "vote_average": 8.2,
          "genre_ids": [28, 878]
        },
        {
          "id": 1,
          "title": "No Poster",
          "overview": "",
          "release_date": "",
          "poster_path": null,
          "vote_average": 0,
          "genre_ids": []
        }
      ]
    }
    """

/// TMDB answers with this JSON when something goes wrong, e.g. with a wrong API key.
private let tmdbStatusJSON = """
    {"status_code": 7, "status_message": "Invalid API key."}
    """

private let testAPIKey = "test-key"
private let testAddress = "https://api.themoviedb.org"

@MainActor
struct TMDBTests {
    @Test func decodesSnakeCaseKeys() throws {
        let movies = try decodeTMDBMovies(Data(popularMoviesJSON.utf8))

        let matrix = try #require(movies.first)
        #expect(matrix.releaseDate == "1999-03-31")
        #expect(matrix.posterPath == "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg")
        #expect(matrix.voteAverage == 8.2)
        #expect(matrix.genreIds == [genreIdAction, genreIdScienceFiction])
    }

    @Test func decodesMissingPosterAsNil() throws {
        let movies = try decodeTMDBMovies(Data(popularMoviesJSON.utf8))

        #expect(movies.count == 2)
        #expect(movies[1].posterPath == nil)
    }

    @Test func decodingFailsForOtherJSON() {
        #expect(throws: DecodingError.self) {
            try decodeTMDBMovies(Data(tmdbStatusJSON.utf8))
        }
    }

    @Test func popularURLHasAPIKey() {
        let popularURL = tmdbPopularURL(apiKey: testAPIKey)

        #expect(
            popularURL?.absoluteString
                == "https://api.themoviedb.org/3/movie/popular?api_key=test-key"
        )
    }

    @Test func searchWithTextUsesSearchEndpoint() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "matrix", genreId: noGenreId, apiKey: testAPIKey)
        )

        #expect(searchURL.path() == "/3/search/movie")
        #expect(queryValue(searchURL, "query") == "matrix")
        #expect(queryValue(searchURL, "api_key") == testAPIKey)
    }

    @Test func searchWithGenreOnlyUsesDiscoverEndpoint() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "  ", genreId: genreIdAnimation, apiKey: testAPIKey)
        )

        #expect(searchURL.path() == "/3/discover/movie")
        #expect(queryValue(searchURL, "with_genres") == String(genreIdAnimation))
        #expect(queryValue(searchURL, "query") == nil)
    }

    @Test func searchTextIsPercentEncoded() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "pan tadeusz", genreId: noGenreId, apiKey: testAPIKey)
        )

        #expect(searchURL.absoluteString.contains("query=pan%20tadeusz"))
    }

    @Test func detailsURLAppendsEveryPart() throws {
        let detailsURL = try #require(tmdbMovieDetailsURL(movieId: 603, apiKey: testAPIKey))

        #expect(detailsURL.path() == "/3/movie/603")
        let appendedParts = try #require(queryValue(detailsURL, "append_to_response"))
        let expectedParts = [
            "credits", "videos", "release_dates", "watch/providers", "recommendations",
        ]
        #expect(appendedParts.split(separator: ",").map(String.init) == expectedParts)
    }

    @Test func okResponsePasses() throws {
        let response = try makeResponse(statusCode: 200)

        #expect(throws: Never.self) {
            try checkTMDBResponse(response)
        }
    }

    @Test func unauthorizedResponseMentionsAPIKey() throws {
        let response = try makeResponse(statusCode: 401)

        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }
        #expect(thrownError?.message.contains("API key") == true)
    }

    @Test func otherErrorResponseShowsStatus() throws {
        let response = try makeResponse(statusCode: 404)

        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }
        #expect(thrownError?.message.contains("404") == true)
    }
}

/// Value of the parameter in the address, nil when the address does not have it.
private func queryValue(_ address: URL, _ parameterName: String) -> String? {
    let queryItems = URLComponents(url: address, resolvingAgainstBaseURL: false)?.queryItems ?? []
    for queryItem in queryItems {
        if queryItem.name == parameterName {
            return queryItem.value
        }
    }
    return nil
}

private func makeResponse(statusCode: Int) throws -> HTTPURLResponse {
    let address = try #require(URL(string: testAddress))
    return try #require(
        HTTPURLResponse(url: address, statusCode: statusCode, httpVersion: nil, headerFields: nil)
    )
}
