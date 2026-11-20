import SwiftUI

private let headerSymbolSize: CGFloat = 56
private let formMaxWidth: CGFloat = 420

/// The first screen of the app, until the user signs in.
struct SignInView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: spacingExtraLarge) {
                header
                fields
                buttons
                status
            }
            .padding()
            .padding(.top, spacingHuge)
            .frame(maxWidth: formMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: spacingSmall) {
            Image(systemName: symbolNameMovies)
                .font(.system(size: headerSymbolSize))
                .foregroundStyle(.tint)
            Text("My Next Movie")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
            Text("Sign in to keep your saved movies on every device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var fields: some View {
        VStack(spacing: spacingMedium) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .onSubmit(signInFromKeyboard)
        }
        .textFieldStyle(.roundedBorder)
    }

    private var buttons: some View {
        VStack(spacing: spacingMedium) {
            Button {
                Task { await viewModel.signIn() }
            } label: {
                Text("Sign In").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSignIn)
            Button {
                Task { await viewModel.signUp() }
            } label: {
                Text("Create Account").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canSignUp)
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private var status: some View {
        if viewModel.state == .loading {
            ProgressView()
        } else if viewModel.state == .failed {
            Label(viewModel.errorMessage, systemImage: symbolNameError)
                .foregroundStyle(.red)
        } else if viewModel.isWaitingForEmailConfirmation {
            Text("Check your email and tap the link to confirm the account, then sign in.")
                .multilineTextAlignment(.center)
        } else {
            Text("A new account needs a password of at least \(minimumPasswordLength) characters.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Return in the password field signs in.
    private func signInFromKeyboard() {
        if viewModel.canSignIn {
            Task { await viewModel.signIn() }
        }
    }
}

#Preview {
    SignInView(viewModel: previewAccountViewModel(signedInEmail: ""))
}
