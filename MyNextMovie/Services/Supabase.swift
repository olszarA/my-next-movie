import Foundation
import Supabase

// Supabase: accounts (Auth) and the `saved_movies` table.
// Row Level Security in the database lets a user see and change only their own rows.

let savedMoviesTable = "saved_movies"
let savedMoviesIdColumn = "id"
let savedMoviesSavedAtColumn = "saved_at"
/// The primary key of `saved_movies`, for `upsert`.
let savedMoviesPrimaryKey = "user_id,id"

let minimumPasswordLength = 6

/// Created by `supabase/seed.sql`. Debug builds fill the sign in screen with it.
let testAccountEmail = "test@test.test"
let testAccountPassword = "test"

private let missingSupabaseKeysMessage =
    "Missing Supabase keys. Add them to Config/Secrets.xcconfig."

/// An error with a message that the screen shows as it is.
nonisolated struct SupabaseError: LocalizedError {
    let message: String

    var errorDescription: String? {
        return message
    }
}

/// One row of `saved_movies`. Without `user_id`, the database fills it in by itself.
nonisolated struct CloudSavedMovie: Codable, Equatable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String
    let posterPath: String?
    let voteAverage: Double
    let genreIds: [Int]
    let savedAt: Date

    /// Column names are snake_case.
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
        case savedAt = "saved_at"
    }
}

// MARK: - Client

/// One client for the whole app, created by the first request.
private var sharedSupabaseClient: SupabaseClient?

private func requireSupabaseClient() throws -> SupabaseClient {
    if let sharedSupabaseClient {
        return sharedSupabaseClient
    }
    let anonKey = supabaseAnonKey()
    guard let projectURL = URL(string: supabaseURL()), projectURL.host() != nil, !anonKey.isEmpty
    else {
        throw SupabaseError(message: missingSupabaseKeysMessage)
    }
    let client = SupabaseClient(supabaseURL: projectURL, supabaseKey: anonKey)
    sharedSupabaseClient = client
    return client
}

// MARK: - Account

/// The client keeps the session in the keychain, so this works also without the network.
func supabaseSignedInEmail() -> String {
    let client = try? requireSupabaseClient()
    return client?.auth.currentUser?.email ?? ""
}

func signInToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let session = try await client.auth.signIn(email: email, password: password)
    return session.user.email ?? email
}

/// "" when the account waits for the email confirmation, so there is no session yet.
func signUpToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let response = try await client.auth.signUp(email: email, password: password)
    if response.session == nil {
        return ""
    }
    return response.user.email ?? email
}

/// A server error is skipped, so signing out works also without the network.
func signOutOfSupabase() async throws {
    let client = try requireSupabaseClient()
    try? await client.auth.signOut()
}

let supabaseAccountService = AccountService(
    signedInEmail: supabaseSignedInEmail,
    signIn: signInToSupabase,
    signUp: signUpToSupabase,
    signOut: signOutOfSupabase
)

// MARK: - Saved movies

/// Rows of the table, the newest first. RLS returns only the rows of the signed-in user.
func fetchCloudSavedMovies() async throws -> [CloudSavedMovie] {
    let client = try requireSupabaseClient()
    let query = client.from(savedMoviesTable)
        .select()
        .order(savedMoviesSavedAtColumn, ascending: false)
    let cloudMovies: [CloudSavedMovie] = try await query.execute().value
    return cloudMovies
}

/// Adds the rows. A movie the account already has stays as it is.
func uploadCloudSavedMovies(_ cloudMovies: [CloudSavedMovie]) async throws {
    if cloudMovies.isEmpty {
        return
    }
    let client = try requireSupabaseClient()
    let query = try client.from(savedMoviesTable)
        .upsert(
            cloudMovies,
            onConflict: savedMoviesPrimaryKey,
            returning: .minimal,
            ignoreDuplicates: true
        )
    _ = try await query.execute()
}

func removeCloudSavedMovie(movieId: Int) async throws {
    let client = try requireSupabaseClient()
    let query = client.from(savedMoviesTable)
        .delete(returning: .minimal)
        .eq(savedMoviesIdColumn, value: movieId)
    _ = try await query.execute()
}

let supabaseSavedMoviesCloud = SavedMoviesCloud(
    fetchMovies: fetchCloudSavedMovies,
    uploadMovies: uploadCloudSavedMovies,
    removeMovie: removeCloudSavedMovie
)
