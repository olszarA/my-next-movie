/// Signs in or creates an account and returns the email of the signed-in user.
/// An empty string means the account waits for the email confirmation.
typealias AccountRequest = (_ email: String, _ password: String) async throws -> String

/// The account functions the view model gets. The app passes Supabase, the tests closures.
struct AccountService {
    let signedInEmail: @MainActor () -> String
    let signIn: AccountRequest
    let signUp: AccountRequest
    let signOut: () async throws -> Void
}

/// The `saved_movies` table of the signed-in user. The app passes Supabase, the tests an array.
struct SavedMoviesCloud {
    let fetchMovies: () async throws -> [CloudSavedMovie]
    let uploadMovies: (_ cloudMovies: [CloudSavedMovie]) async throws -> Void
    let removeMovie: (_ movieId: Int) async throws -> Void
}
