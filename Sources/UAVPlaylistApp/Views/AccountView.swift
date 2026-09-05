import SwiftUI

/// Sign in to a MissAV account so its saved playlists show up as categories.
struct AccountView: View {
    @ObservedObject private var account = MissAVAccount.shared

    @State private var email = ""
    @State private var password = ""
    @State private var remember = true
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        Form {
            if account.isSignedIn {
                Section("Signed in") {
                    LabeledContent("MissAV", value: account.email)
                    Button("Refresh playlists") { Task { await refresh() } }
                        .disabled(account.isWorking)
                    Button("Sign out", role: .destructive) {
                        account.signOut()
                        statusMessage = nil
                        errorMessage = nil
                    }
                }

                Section("Saved playlists (\(account.playlists.count))") {
                    if account.playlists.isEmpty {
                        Text("No playlists found on this account.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(account.playlists) { playlist in
                            Text(playlist.name)
                        }
                    }
                }
            } else {
                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    Toggle("Remember me", isOn: $remember)

                    Button {
                        Task { await signIn() }
                    } label: {
                        if account.isWorking {
                            ProgressView()
                        } else {
                            Text("Sign in to MissAV")
                        }
                    }
                    .disabled(account.isWorking || email.isEmpty || password.isEmpty)
                } header: {
                    Text("MissAV account")
                } footer: {
                    Text("Your credentials are sent only to missav.ai, and are stored in this device's Keychain when \"Remember me\" is on. Signing out deletes them and clears the session.")
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
            if let statusMessage {
                Section { Text(statusMessage).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Account")
        .task { await account.restoreSession() }
    }

    private func signIn() async {
        errorMessage = nil
        statusMessage = nil
        do {
            try await account.signIn(email: email, password: password, remember: remember)
            password = ""
            statusMessage = "Signed in. Your playlists appear under MissAV in the Browse tab."
        } catch let error as MissAVAccount.AccountError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refresh() async {
        errorMessage = nil
        statusMessage = nil
        do {
            let fetched = try await account.refreshPlaylists()
            statusMessage = "Found \(fetched.count) playlist(s)."
        } catch let error as MissAVAccount.AccountError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
