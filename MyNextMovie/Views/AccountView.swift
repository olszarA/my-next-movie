import SwiftUI

/// The Account tab: who is signed in, the sync of saved movies and signing out.
struct AccountView: View {
    let viewModel: AccountViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Signed in as") { Text(viewModel.signedInEmail) }
                Section("Saved movies") { syncStatus }
                signOutSection
            }
            .navigationTitle("Account")
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        switch viewModel.syncState {
        case .idle, .loading:
            HStack(spacing: spacingMedium) {
                ProgressView()
                Text("Syncing with your account")
            }
        case .loaded:
            Label("In sync with your account", systemImage: symbolNameSyncDone)
        case .failed:
            Label(viewModel.syncErrorMessage, systemImage: symbolNameSyncFailed)
                .foregroundStyle(.red)
            Button("Try again") {
                Task { await viewModel.syncSavedMovies() }
            }
        }
    }

    private var signOutSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
        } footer: {
            Text("Your saved movies stay in your account and leave this device.")
        }
    }
}

/// A view model for previews: any email and password sign in, nothing is synced.
func previewAccountViewModel(signedInEmail: String) -> AccountViewModel {
    let previewAccount = AccountService(
        signedInEmail: { signedInEmail },
        signIn: { email, _ in email },
        signUp: { email, _ in email },
        signOut: {}
    )
    return AccountViewModel(account: previewAccount, syncSavedMovies: {}, clearSavedMovies: {})
}

#Preview {
    AccountView(viewModel: previewAccountViewModel(signedInEmail: testAccountEmail))
}
