import Foundation
import Observation

/// State of the account and of the sync of saved movies.
/// A class only because SwiftUI's @Observable requires one.
@Observable
final class AccountViewModel {
    var email = ""
    var password = ""
    /// Empty when nobody is signed in.
    private(set) var signedInEmail = ""
    private(set) var state = LoadState.idle
    private(set) var errorMessage = ""
    private(set) var isWaitingForEmailConfirmation = false
    private(set) var syncState = LoadState.idle
    private(set) var syncErrorMessage = ""

    private let account: AccountService
    private let syncWithAccount: () async throws -> Void
    private let clearDevice: @MainActor () -> Void

    /// Two syncs at once would change the list at the same time.
    /// A sync asked for during another one runs right after it.
    private var isSyncing = false
    private var isSyncRequested = false

    init(
        account: AccountService,
        syncSavedMovies: @escaping () async throws -> Void,
        clearSavedMovies: @escaping @MainActor () -> Void
    ) {
        self.account = account
        self.syncWithAccount = syncSavedMovies
        self.clearDevice = clearSavedMovies
        // Read at once, so a user signed in last time never sees the sign in screen.
        self.signedInEmail = account.signedInEmail()
    }

    var isSignedIn: Bool {
        return !signedInEmail.isEmpty
    }

    var canSignIn: Bool {
        return !trimmedEmail.isEmpty && !password.isEmpty && state != .loading
    }

    var canSignUp: Bool {
        return canSignIn && password.count >= minimumPasswordLength
    }

    func signIn() async {
        await submit(account.signIn)
    }

    func signUp() async {
        await submit(account.signUp)
    }

    func syncSavedMovies() async {
        if !isSignedIn {
            return
        }
        if isSyncing {
            isSyncRequested = true
            return
        }
        isSyncing = true
        repeat {
            isSyncRequested = false
            await syncOnce()
        } while isSyncRequested
        isSyncing = false
    }

    /// Sends the last changes first, so they are not lost, then signs out
    /// and removes the saved movies from this device. The account keeps them.
    func signOut() async {
        await syncSavedMovies()
        do {
            try await account.signOut()
        } catch {
            syncErrorMessage = error.localizedDescription
            syncState = .failed
            return
        }
        signedInEmail = ""
        state = .idle
        syncState = .idle
        clearDevice()
    }

    private var trimmedEmail: String {
        return email.trimmingCharacters(in: .whitespaces)
    }

    /// Signing in and creating an account are the same path with another request.
    private func submit(_ request: AccountRequest) async {
        state = .loading
        isWaitingForEmailConfirmation = false
        do {
            let accountEmail = try await request(trimmedEmail, password)
            password = ""
            state = .loaded
            if accountEmail.isEmpty {
                isWaitingForEmailConfirmation = true
                return
            }
            signedInEmail = accountEmail
            await syncSavedMovies()
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    private func syncOnce() async {
        syncState = .loading
        do {
            try await syncWithAccount()
            syncState = .loaded
        } catch {
            syncErrorMessage = error.localizedDescription
            syncState = .failed
        }
    }
}
