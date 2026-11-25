import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct AuthenticationScreen: View {
    @EnvironmentObject private var connection: KaarisConnection
    @FocusState private var focusedField: Field?
    @State private var email = ""
    @State private var password = ""
    @State private var signUp = false
    @State private var appleNonce: String?
    @State private var appleNotice: String?

    private enum Field {
        case email, password
    }

    private var busy: Bool { connection.authWorking || appleNonce != nil }
    private var available: Bool { connection.authConfigured && !busy }
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSubmit: Bool { available && trimmedEmail.contains("@") && !password.isEmpty }

    var body: some View {
        KPage {
            BrandMark()
            VStack(alignment: .leading, spacing: 8) {
                KTitle(text: signUp ? "CRÉE TON COMPTE" : "CONNECTE-TOI")
                Text("Retrouve ton programme, tes séances et tes progrès.")
                    .foregroundStyle(muted)
            }

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue, onRequest: prepareAppleSignIn, onCompletion: finishAppleSignIn)
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .disabled(!available)
                Button {
                    focusedField = nil
                    appleNotice = nil
                    Task { await connection.signInWithGoogle() }
                } label: {
                    Text("Continuer avec Google")
                }
                .buttonStyle(ActionStyle(filled: false))
                .disabled(!available)
            }

            emailForm

            if busy {
                ProgressView("Connexion en cours…")
                    .tint(acid)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let notice = appleNotice ?? connection.authNotice {
                Label(notice, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(muted)
            } else if !connection.authConfigured {
                Label("La connexion est indisponible dans cette version.", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(muted)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Par e-mail")
            TextField("Adresse e-mail", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }
                .padding(12)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            SecureField("Mot de passe", text: $password)
                .textContentType(signUp ? .newPassword : .password)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit(submitEmail)
                .padding(12)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

            Button(signUp ? "Créer mon compte" : "Me connecter", action: submitEmail)
                .buttonStyle(ActionStyle())
                .disabled(!canSubmit)
            Button(signUp ? "J’ai déjà un compte" : "Créer un compte KAARIS") {
                signUp.toggle()
                password = ""
                appleNotice = nil
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(acid)
            .frame(minHeight: 44)
        }
        .kPanel()
        .disabled(!available)
    }

    private func submitEmail() {
        guard canSubmit else { return }
        focusedField = nil
        appleNotice = nil
        let submittedEmail = trimmedEmail
        let submittedPassword = password
        let createsAccount = signUp
        password = ""
        Task {
            await connection.authenticate(email: submittedEmail, password: submittedPassword, signUp: createsAccount)
        }
    }

    private func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        focusedField = nil
        appleNotice = nil

        var random = Data(count: 32)
        let status = random.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let bytes = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, bytes)
        }
        guard status == errSecSuccess else {
            appleNotice = "La connexion Apple n’a pas pu démarrer. Réessaie."
            return
        }

        let nonce = random.map { String(format: "%02x", $0) }.joined()
        appleNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func finishAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard let nonce = appleNonce else { return }
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  !token.isEmpty else {
                appleNonce = nil
                appleNotice = "Apple n’a pas renvoyé de jeton de connexion. Réessaie."
                return
            }
            Task {
                defer { appleNonce = nil }
                await connection.signInWithApple(idToken: token, nonce: nonce)
            }
        case .failure(let error):
            appleNonce = nil
            if (error as? ASAuthorizationError)?.code == .canceled {
                appleNotice = "Connexion Apple annulée."
            } else {
                appleNotice = "La connexion Apple a échoué. Réessaie."
            }
        }
    }
}

struct AccountLockScreen: View {
    let message: String?
    let unlocking: Bool
    let unlock: () -> Void
    let signOut: () -> Void

    var body: some View {
        KPage {
            BrandMark()
            VStack(alignment: .leading, spacing: 8) {
                KTitle(text: "SESSION VERROUILLÉE")
                Text(message ?? "Vérifie ta session pour retrouver ton programme.")
                    .foregroundStyle(muted)
            }
            Button(action: unlock) {
                if unlocking {
                    ProgressView("Vérification…")
                        .tint(ink)
                } else {
                    Text("Vérifier ma session")
                }
            }
            .buttonStyle(ActionStyle())
            .disabled(unlocking)
            Button("Se reconnecter", action: signOut)
                .buttonStyle(ActionStyle(filled: false))
                .disabled(unlocking)
        }
    }
}
