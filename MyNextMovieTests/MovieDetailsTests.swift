import Foundation
import Testing

@testable import MyNextMovie

/// Details of The Matrix, shortened. The second actor has no photo, the director is listed twice,
/// an unofficial trailer comes before the official one, in Poland a release without a rating
/// comes before the one with "16", and in Poland the movie is to stream and to rent.
private let matrixDetailsJSON = """
    {
      "id": 603,
      "tagline": "Believe the unbelievable.",
      "runtime": 136,
      "credits": {
        "cast": [
          {"id": 6384, "name": "Keanu Reeves", "character": "Neo", "profile_path": "/8RZL.jpg"},
          {"id": 530, "name": "Carrie-Anne Moss", "character": "Trinity", "profile_path": null}
        ],
        "crew": [
          {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
          {"id": 9340, "name": "Lana Wachowski", "job": "Writer"},
          {"id": 9339, "name": "Lilly Wachowski", "job": "Director"},
          {"id": 9340, "name": "Lana Wachowski", "job": "Director"}
        ]
      },
      "videos": {
        "results": [
          {"key": "fanMade1", "site": "YouTube", "type": "Trailer", "official": false},
          {"key": "vKQi3bBA1y8", "site": "YouTube", "type": "Trailer", "official": true}
        ]
      },
      "release_dates": {
        "results": [
          {
            "iso_3166_1": "PL",
            "release_dates": [
              {"certification": "", "release_date": "1999-06-01T00:00:00.000Z", "type": 1},
              {"certification": "16", "release_date": "1999-06-25T00:00:00.000Z", "type": 3}
            ]
          },
          {
            "iso_3166_1": "US",
            "release_dates": [
              {"certification": "R", "release_date": "1999-03-31T00:00:00.000Z", "type": 3}
            ]
          }
        ]
      },
      "watch/providers": {
        "results": {
          "PL": {
            "link": "https://www.themoviedb.org/movie/603-the-matrix/watch?locale=PL",
            "flatrate": [
              {"provider_id": 119, "provider_name": "Amazon Prime Video", "logo_path": "/gMZd.png"}
            ],
            "rent": [
              {"provider_id": 2, "provider_name": "Apple TV", "logo_path": "/peUR.png"}
            ]
          }
        }
      },
      "recommendations": {
        "page": 1,
        "results": [
          {
            "id": 604,
            "title": "The Matrix Reloaded",
            "overview": "Neo and the rebels fight the machines.",
            "release_date": "2003-05-15",
            "poster_path": "/9TGHDvWrqKBzwDxDodHYXEmOE6J.jpg",
            "vote_average": 7.1,
            "genre_ids": [28, 878]
          }
        ]
      }
    }
    """

/// An announced movie: TMDB does not know its length and has no lists yet.
private let announcedMovieJSON = """
    {
      "id": 1,
      "tagline": "",
      "runtime": null,
      "credits": {"cast": [], "crew": []},
      "videos": {"results": []},
      "release_dates": {"results": []},
      "watch/providers": {"results": {}},
      "recommendations": {"page": 1, "results": []}
    }
    """

@MainActor
private func decodeMatrixDetails() throws -> MovieDetails {
    return try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))
}

@MainActor
struct MovieDetailsDecodingTests {
    @Test func decodesTaglineAndRuntime() throws {
        let details = try decodeMatrixDetails()

        #expect(details.id == 603)
        #expect(details.tagline == "Believe the unbelievable.")
        #expect(details.runtime == 136)
    }

    @Test func decodesCastWithAndWithoutPhoto() throws {
        let cast = try decodeMatrixDetails().credits.cast

        #expect(cast.count == 2)
        #expect(cast[0].profilePath == "/8RZL.jpg")
        #expect(cast[1].profilePath == nil)
    }

    @Test func decodesWatchProvidersUnderSlashKey() throws {
        let polishProviders = try #require(decodeMatrixDetails().watchProviders.results["PL"])

        #expect(polishProviders.flatrate?.first?.providerName == "Amazon Prime Video")
        #expect(polishProviders.rent?.first?.providerName == "Apple TV")
        #expect(polishProviders.buy == nil)
    }

    @Test func decodesCountryCodeOfReleaseDates() throws {
        let countries = try decodeMatrixDetails().releaseDates.results

        #expect(countries.first?.countryCode == "PL")
    }

    @Test func decodesRecommendationsAsMovies() throws {
        let recommendedMovies = try decodeMatrixDetails().recommendations.results

        #expect(recommendedMovies.count == 1)
        #expect(recommendedMovies.first?.title == "The Matrix Reloaded")
        #expect(recommendedMovies.first?.genreIds == [genreIdAction, genreIdScienceFiction])
    }

    @Test func decodesAnnouncedMovieWithoutRuntime() throws {
        let details = try decodeTMDBMovieDetails(Data(announcedMovieJSON.utf8))

        #expect(details.runtime == nil)
        #expect(formattedRuntime(details) == "")
        #expect(!hasWatchProviders(watchProviders(details, regionCode: "PL")))
    }
}

@MainActor
struct MovieDetailsTests {
    @Test func runtimeInHoursAndMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 136)) == "2h 16m")
        #expect(formattedRuntime(makeMovieDetails(runtime: 120)) == "2h 0m")
    }

    @Test func runtimeUnderAnHourHasOnlyMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 45)) == "45m")
    }

    @Test func runtimeIsEmptyWhenUnknown() {
        #expect(formattedRuntime(makeMovieDetails(runtime: nil)) == "")
        #expect(formattedRuntime(makeMovieDetails(runtime: 0)) == "")
    }

    @Test func directorsAreListedOnceEach() throws {
        #expect(directorNames(try decodeMatrixDetails()) == "Lana Wachowski, Lilly Wachowski")
    }

    @Test func directorsAreEmptyWithoutDirector() {
        #expect(directorNames(makeMovieDetails()) == "")
    }

    @Test func certificationSkipsEmptyOnes() throws {
        let details = try decodeMatrixDetails()

        #expect(ageCertification(details, regionCode: "PL") == "16")
        #expect(ageCertification(details, regionCode: "US") == "R")
    }

    @Test func certificationIsEmptyForOtherCountry() throws {
        #expect(ageCertification(try decodeMatrixDetails(), regionCode: "DE") == "")
    }

    @Test func officialTrailerWins() throws {
        #expect(trailerKey(try decodeMatrixDetails()) == "vKQi3bBA1y8")
    }

    @Test func unofficialTrailerWhenNoOfficial() {
        let details = makeMovieDetails(videos: [
            Video(key: "teaser", site: "YouTube", type: "Teaser", official: true),
            Video(key: "fanMade1", site: "YouTube", type: "Trailer", official: false),
            Video(key: "fanMade2", site: "YouTube", type: "Trailer", official: false),
        ])

        #expect(trailerKey(details) == "fanMade1")
    }

    @Test func trailerOnOtherSiteIsSkipped() {
        let details = makeMovieDetails(videos: [
            Video(key: "vimeoTrailer", site: "Vimeo", type: "Trailer", official: true)
        ])

        #expect(trailerKey(details) == "")
        #expect(trailerURL(details) == nil)
        #expect(!hasTrailer(details))
    }

    @Test func trailerURLPointsToYouTube() throws {
        let details = try decodeMatrixDetails()

        #expect(trailerURL(details) == URL(string: "https://www.youtube.com/watch?v=vKQi3bBA1y8"))
    }

    @Test func factsLineAddsRuntimeAndCertification() throws {
        let matrix = makeMovie(releaseDate: "1999-03-31", voteAverage: 8.2)
        let details = try decodeMatrixDetails()

        #expect(movieFactsLine(matrix, details, regionCode: "PL") == "1999 · ★ 8.2 · 2h 16m · 16")
    }

    @Test func factsLineBeforeDetailsLoad() {
        let matrix = makeMovie(releaseDate: "1999-03-31", voteAverage: 8.2)

        #expect(movieFactsLine(matrix, emptyMovieDetails, regionCode: "PL") == "1999 · ★ 8.2")
    }

    @Test func profileURLIsNilWithoutPhoto() throws {
        let cast = try decodeMatrixDetails().credits.cast

        #expect(profileURL(cast[0]) == URL(string: "https://image.tmdb.org/t/p/w185/8RZL.jpg"))
        #expect(profileURL(cast[1]) == nil)
    }
}

/// Short details for testing one function at a time, like `makeMovie`.
@MainActor
func makeMovieDetails(runtime: Int? = nil, videos: [Video] = []) -> MovieDetails {
    return MovieDetails(
        id: 1,
        tagline: "",
        runtime: runtime,
        credits: Credits(cast: [], crew: []),
        videos: VideoList(results: videos),
        releaseDates: ReleaseDateList(results: []),
        watchProviders: WatchProviderList(results: [:]),
        recommendations: TMDBMoviePage(results: [])
    )
}
