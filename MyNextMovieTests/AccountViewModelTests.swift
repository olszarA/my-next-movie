import Testing

@testable import MyNextMovie

private let testEmail = "ola@example.com"
private let testPassword = "secret1"
private let shortPassword = "abc"

/// Pretends to be Supabase. A class, so the closures and the test see the same fields.
@MainActor
private final class TestAccount {
    var signedInEmail = ""
    var isOffline = false
    var needsEmailConfirmation = false
    var isSyncFailing = false
    var sentEmails: [String] = []
    /// Every call in order: "sync", "signOut" and "clear".
    var calls: [String] = []

    func request(email: String, password: String) throws -> String {
        if isOffline {
            throw NoConnection()
        }
        sentEmails.append(email)
        if needsEmailConfirmation {
            return ""
        }
        signedInEmail = email
        return email
    }

    func syncCount() -> Int {
        var count = 0
        for call in calls {
            if call == "sync" {
                count += 1
            }
        }
        return count
    }
}

@MainActor
private func makeViewModel(_ testAccount: TestAccount) -> AccountViewModel {
    let service = AccountService(
        signedInEmail: { testAccount.signedInEmail },
        signIn: { email, password in try testAccount.request(email: email, password: password) },
        signUp: { email, password in try testAccount.request(email: email, password: password) },
        signOut: {
            testAccount.calls.append("signOut")
            testAccount.signedInEmail = ""
        }
    )
    return AccountViewModel(
        account: service,
        syncSavedMovies: {
            testAccount.calls.append("sync")
            if testAccount.isSyncFailing {
                throw NoConnection()
            }
        },
        clearSavedMovies: { testAccount.calls.append("clear") }
    )
}

@MainActor
struct AccountViewModelTests {
    @Test func startsSignedOut() {
        let viewModel = makeViewModel(TestAccount())

        #expect(!viewModel.isSignedIn)
        #expect(viewModel.state == .idle)
    }

    @Test func newAccountNeedsLongEnoughPassword() {
        let viewModel = makeViewModel(TestAccount())
        viewModel.email = testEmail
        viewModel.password = shortPassword

        #expect(viewModel.canSignIn)
        #expect(!viewModel.canSignUp)

        viewModel.password = testPassword
        #expect(viewModel.canSignUp)
    }

    @Test func signInTrimsEmailClearsPasswordAndSyncs() async {
        let testAccount = TestAccount()
        let viewModel = makeViewModel(testAccount)
        viewModel.email = "  " + testEmail + " "
        viewModel.password = testPassword

        await viewModel.signIn()

        #expect(testAccount.sentEmails == [testEmail])
        #expect(viewModel.signedInEmail == testEmail)
        #expect(viewModel.password.isEmpty)
        #expect(testAccount.syncCount() == 1)
        #expect(viewModel.syncState == .loaded)
    }

    @Test func showsErrorWhenSignInFails() async {
        let testAccount = TestAccount()
        testAccount.isOffline = true
        let viewModel = makeViewModel(testAccount)
        viewModel.email = testEmail
        viewModel.password = testPassword

        await viewModel.signIn()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
        #expect(!viewModel.isSignedIn)
    }

    @Test func signUpSignsInWhenNoConfirmationIsNeeded() async {
        let viewModel = makeViewModel(TestAccount())
        viewModel.email = testEmail
        viewModel.password = testPassword

        await viewModel.signUp()

        #expect(viewModel.isSignedIn)
        #expect(!viewModel.isWaitingForEmailConfirmation)
    }

    @Test func signUpWaitsForEmailConfirmation() async {
        let testAccount = TestAccount()
        testAccount.needsEmailConfirmation = true
        let viewModel = makeViewModel(testAccount)
        viewModel.email = testEmail
        viewModel.password = testPassword

        await viewModel.signUp()

        #expect(viewModel.isWaitingForEmailConfirmation)
        #expect(!viewModel.isSignedIn)
        #expect(testAccount.syncCount() == 0)
    }

    @Test func userFromLastTimeIsSignedInAtOnce() {
        let testAccount = TestAccount()
        testAccount.signedInEmail = testEmail

        let viewModel = makeViewModel(testAccount)

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedInEmail == testEmail)
    }

    @Test func doesNotSyncWhenSignedOut() async {
        let testAccount = TestAccount()
        let viewModel = makeViewModel(testAccount)

        await viewModel.syncSavedMovies()

        #expect(testAccount.calls.isEmpty)
        #expect(viewModel.syncState == .idle)
    }

    @Test func showsErrorWhenSyncFails() async {
        let testAccount = TestAccount()
        testAccount.signedInEmail = testEmail
        testAccount.isSyncFailing = true
        let viewModel = makeViewModel(testAccount)

        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .failed)
        #expect(viewModel.syncErrorMessage == "No connection")
    }

    @Test func syncWorksAgainAfterFailure() async {
        let testAccount = TestAccount()
        testAccount.signedInEmail = testEmail
        testAccount.isSyncFailing = true
        let viewModel = makeViewModel(testAccount)
        await viewModel.syncSavedMovies()

        testAccount.isSyncFailing = false
        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .loaded)
        #expect(testAccount.syncCount() == 2)
    }

    @Test func signOutSyncsThenClearsDevice() async {
        let testAccount = TestAccount()
        testAccount.signedInEmail = testEmail
        let viewModel = makeViewModel(testAccount)

        await viewModel.signOut()

        #expect(testAccount.calls == ["sync", "signOut", "clear"])
        #expect(!viewModel.isSignedIn)
    }
}
