import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppStore.self) private var store

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var remember = true
    @State private var error: AuthService.LoginError? = nil
    @State private var secondsLeft = 0
    @FocusState private var focus: AuthService.Field?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AssemblingLogo(size: 60)
                    .padding(.bottom, 22)

                Text("Entra a Liminal")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text("Tu IA en español, privada y a precio justo.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.bottom, 26)

                VStack(alignment: .leading, spacing: 0) {
                    TrafficLights()
                        .padding(.bottom, 18)

                    // Apple's official button. It needs the paid developer account and the server to work.
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success:
                            store.show("Demostración: con el servidor conectado, aquí se crea o se abre tu cuenta.")
                        case .failure:
                            store.show("Entrar con Apple necesita la cuenta de desarrollador de Apple y el servidor de Liminal.")
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 10)

                    Button {
                        store.show("Demostración: con el servidor conectado se abre Google y entras sin contraseña.")
                    } label: {
                        Label("Continuar con Google", systemImage: "globe")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.line2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)

                    HStack(spacing: 10) {
                        Rectangle().fill(Palette.line).frame(height: 1)
                        Text("o con tu correo")
                            .font(.caption)
                            .foregroundStyle(Palette.ink3)
                            .fixedSize()
                        Rectangle().fill(Palette.line).frame(height: 1)
                    }
                    .padding(.bottom, 16)

                    fieldLabel("Correo")
                    TextField("tu@correo.com", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                        .foregroundStyle(Palette.ink)
                        .inputBox(invalid: error?.field == .email)
                        .padding(.bottom, 16)

                    fieldLabel("Contraseña")
                    HStack(spacing: 8) {
                        Group {
                            if showPassword {
                                TextField("Tu contraseña", text: $password)
                            } else {
                                SecureField("Tu contraseña", text: $password)
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                        .foregroundStyle(Palette.ink)

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(Palette.ink3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showPassword ? "Ocultar contraseña" : "Mostrar contraseña")
                    }
                    .inputBox(invalid: error?.field == .password)
                    .padding(.bottom, 14)

                    HStack {
                        Toggle("Recordarme", isOn: $remember)
                            .tint(Palette.green)
                            .fixedSize()
                        Spacer()
                        Button("¿Olvidaste tu contraseña?") {
                            store.show("Pronto podrás recuperarla con un enlace a tu correo.")
                        }
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, 16)

                    if let error {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: secondsLeft > 0 ? "lock.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(Palette.red)
                            Text(secondsLeft > 0 ? AuthService.LoginError.locked(seconds: secondsLeft).message : error.message)
                                .font(.footnote)
                                .foregroundStyle(Palette.redText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.redTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.bottom, 14)
                        .transition(.opacity)
                        .accessibilityElement(children: .combine)
                    }

                    Button(action: submit) {
                        Text(secondsLeft > 0 ? "Espera \(secondsLeft) s" : "Entrar")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Palette.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.ink.opacity(secondsLeft > 0 ? 0.35 : 1),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(secondsLeft > 0)
                }
                .padding(20)
                .background(Palette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.2), value: error)

                HStack(spacing: 4) {
                    Text("¿No tienes cuenta?")
                        .foregroundStyle(Palette.ink3)
                    Button("Crear cuenta") {
                        store.show("El registro abre con el lanzamiento. Por ahora, solo entra la cuenta de administración.")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.ink)
                }
                .font(.subheadline)
                .padding(.top, 20)

                Text("Versión de prueba. El acceso funciona solo en este dispositivo hasta conectar el servidor.")
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 24)
            .padding(.vertical, 56)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
        .onAppear {
            if let lockedUntil = auth.lockedUntil, lockedUntil > Date() {
                secondsLeft = max(1, Int(lockedUntil.timeIntervalSinceNow.rounded(.up)))
                error = .locked(seconds: secondsLeft)
            }
        }
        .task(id: secondsLeft > 0) {
            while secondsLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                secondsLeft -= 1
            }
            if case .locked? = error {
                error = nil
            }
        }
        .onChange(of: email) {
            if error?.field == .email { error = nil }
        }
        .onChange(of: password) {
            if error?.field == .password && !password.isEmpty { error = nil }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.ink2)
            .padding(.bottom, 6)
    }

    private func submit() {
        guard secondsLeft == 0 else { return }
        if let result = auth.signIn(email: email, password: password, remember: remember) {
            error = result
            switch result {
            case .locked(let seconds):
                secondsLeft = seconds
                password = ""
                focus = nil
            case .wrongCredentials:
                password = ""
                focus = .password
            default:
                focus = result.field
            }
        } else {
            error = nil
            password = ""
            focus = nil
            store.checkUsage()
        }
    }
}
