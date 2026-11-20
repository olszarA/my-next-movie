import Foundation

// TMDB REST API. See https://developer.themoviedb.org/reference/intro/getting-started

private let tmdbScheme = "https"
private let tmdbHost = "api.themoviedb.org"

let tmdbPopularPath = "/3/movie/popular"
let tmdbSearchPath = "/3/search/movie"
let tmdbDiscoverPath = "/3/discover/movie"
let tmdbMovieDetailsPathPrefix = "/3/movie/"

let tmdbParameterAPIKey = "api_key"
let tmdbParameterQuery = "query"
let tmdbParameterWithGenres = "with_genres"
let tmdbParameterAppendToResponse = "append_to_response"

/// Parts of the details answer that TMDB sends in the same request.
let tmdbDetailsAppendedParts = "credits,videos,release_dates,watch/providers,recommendations"

let httpStatusOK = 200
let httpStatusUnauthorized = 401

private let missingTMDBAPIKeyMessage = "Missing TMDB API key. Add it to Config/Secrets.xcconfig."
private let rejectedTMDBAPIKeyMessage =
    "TMDB did not accept the API key. Check it in Config/Secrets.xcconfig."
private let invalidTMDBAddressMessage = "Could not build the TMDB address."

/// One page of a TMDB movie list.
nonisolated struct TMDBMoviePage: Decodable {
    let results: [Movie]
}

/// An error with a message that the screen shows as it is.
nonisolated struct TMDBError: LocalizedError {
    let message: String

    var errorDescription: String? {
        return message
    }
}

// MARK: - Addresses

/// TMDB address with `api_key` as the first parameter, then `parameters`.
func tmdbURL(path: String, parameters: [URLQueryItem], apiKey: String) -> URL? {
    var components = URLComponents()
    components.scheme = tmdbScheme
    components.host = tmdbHost
    components.path = path
    let apiKeyParameter = URLQueryItem(name: tmdbParameterAPIKey, value: apiKey)
    components.queryItems = [apiKeyParameter] + parameters
    return components.url
}

func tmdbPopularURL(apiKey: String) -> URL? {
    return tmdbURL(path: tmdbPopularPath, parameters: [], apiKey: apiKey)
}

/// With text `/search/movie` with `query`. Without text `/discover/movie` with `with_genres`.
func tmdbSearchURL(query: String, genreId: Int, apiKey: String) -> URL? {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    if trimmedQuery.isEmpty {
        var genreParameters: [URLQueryItem] = []
        if genreId != noGenreId {
            let genreValue = String(genreId)
            genreParameters.append(URLQueryItem(name: tmdbParameterWithGenres, value: genreValue))
        }
        return tmdbURL(path: tmdbDiscoverPath, parameters: genreParameters, apiKey: apiKey)
    }
    let queryParameter = URLQueryItem(name: tmdbParameterQuery, value: trimmedQuery)
    return tmdbURL(path: tmdbSearchPath, parameters: [queryParameter], apiKey: apiKey)
}

/// Details of one movie with every part from `tmdbDetailsAppendedParts`.
func tmdbMovieDetailsURL(movieId: Int, apiKey: String) -> URL? {
    let appendParameter = URLQueryItem(
        name: tmdbParameterAppendToResponse,
        value: tmdbDetailsAppendedParts
    )
    let path = tmdbMovieDetailsPathPrefix + String(movieId)
    return tmdbURL(path: path, parameters: [appendParameter], apiKey: apiKey)
}

// MARK: - Answers

func decodeTMDBMovies(_ data: Data) throws -> [Movie] {
    let moviePage = try makeTMDBDecoder().decode(TMDBMoviePage.self, from: data)
    return moviePage.results
}

func decodeTMDBMovieDetails(_ data: Data) throws -> MovieDetails {
    return try makeTMDBDecoder().decode(MovieDetails.self, from: data)
}

/// TMDB JSON keys are snake_case, Swift fields camelCase.
private func makeTMDBDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}

/// `URLSession` does not throw for 401 or 404, so the status is checked here.
func checkTMDBResponse(_ response: URLResponse) throws {
    let httpResponse = response as? HTTPURLResponse
    let statusCode = httpResponse?.statusCode ?? httpStatusOK
    if statusCode == httpStatusUnauthorized {
        throw TMDBError(message: rejectedTMDBAPIKeyMessage)
    }
    if statusCode != httpStatusOK {
        throw TMDBError(message: "TMDB answered with HTTP status \(statusCode).")
    }
}

// MARK: - Requests

/// Has the type `MovieLoader`.
func fetchPopularMovies() async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchTMDBData(tmdbPopularURL(apiKey: apiKey))
    return try decodeTMDBMovies(data)
}

/// Has the type `MovieSearch`. `/search/movie` cannot filter by genre,
/// so the found movies are filtered here.
func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    let searchAddress = tmdbSearchURL(query: trimmedQuery, genreId: genreId, apiKey: apiKey)
    let data = try await fetchTMDBData(searchAddress)
    let foundMovies = try decodeTMDBMovies(data)
    return filterMovies(foundMovies, query: "", genreId: genreId)
}

/// Has the type `MovieDetailsLoader`.
func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchTMDBData(tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey))
    return try decodeTMDBMovieDetails(data)
}

private func requireTMDBAPIKey() throws -> String {
    let apiKey = tmdbAPIKey()
    if apiKey.isEmpty {
        throw TMDBError(message: missingTMDBAPIKeyMessage)
    }
    return apiKey
}

/// Sends the request, checks the status and returns the JSON. Every request goes through here.
private func fetchTMDBData(_ address: URL?) async throws -> Data {
    guard let address else {
        throw TMDBError(message: invalidTMDBAddressMessage)
    }
    let (data, response) = try await URLSession.shared.data(from: address)
    try checkTMDBResponse(response)
    return data
}
