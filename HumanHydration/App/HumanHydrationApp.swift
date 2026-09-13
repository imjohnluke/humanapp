import SwiftUI
import UIKit
import AuthenticationServices
import AVFoundation
import CryptoKit

@main
struct HumanHydrationApp: App {
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .fontDesign(.rounded)
                .fontWeight(.regular)
                .environmentObject(auth)
                .task { await auth.restoreSession() }
                .onOpenURL { auth.handleEmailCallback($0) }
        }
    }
}

private struct LaunchView: View {
    @EnvironmentObject private var auth: AuthService
    var body: some View {
        if auth.isRestoring { ProgressView("Checking your session…") }
        else if let user = auth.user {
            AccountContentView(user: user).id(user.id)
        } else { SignInView() }
    }
}

private struct AccountContentView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var subscriptions: SubscriptionService
    @StateObject private var store: HydrationStore
    @StateObject private var health: HealthKitService
    private let defaults: UserDefaults
    init(user: AuthUser) {
        let defaults = AccountStorage.defaults(for: user.id)
        self.defaults = defaults
        _health = StateObject(wrappedValue: HealthKitService(defaults: defaults))
        _subscriptions = StateObject(wrappedValue: SubscriptionService(accountID: user.id))
        _store = StateObject(wrappedValue: HydrationStore(defaults: defaults, accountID: user.id.uuidString.lowercased()))
    }
    var body: some View {
        AccountRoute().defaultAppStorage(defaults).environmentObject(store)
            .environmentObject(subscriptions)
            .environmentObject(health)
            .task { await health.refresh() }
            .task { await subscriptions.listen(auth: auth) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await subscriptions.reconcileCurrent(auth: auth); await health.refresh() } }
            }
            .onDisappear { ReminderService().cancel() }
    }
}

private struct AccountRoute: View {
    @AppStorage("hasCompletedOnboarding") private var completed = false
    var body: some View {
        if completed { RootView() } else { OnboardingView() }
    }
}

private struct SignInView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var appleNonce: String?
    @State private var logoVisible = false
    @State private var emailStep: EmailStep = .email
    @State private var emailMode: EmailMode = .signUp
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @FocusState private var focusedField: EmailField?

    private enum EmailStep { case email, password, confirmation }
    private enum EmailMode { case signUp, signIn }
    private enum EmailField { case email, password, passwordConfirmation }

    var body: some View {
        ZStack {
            LoopingVideoBackground()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.08).ignoresSafeArea())
            VStack(spacing: 22) {
                Spacer()
                BundledImage(name: "human-logo-wordmark", directory: "DrinkIcons")
                    .frame(width: 190, height: 48)
                    .opacity(logoVisible ? 1 : 0)
                    .offset(y: logoVisible ? 0 : 10)
                Text("the simple way to stay hydrated")
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.white.opacity(0.88))
                    .opacity(logoVisible ? 1 : 0)
                    .offset(y: logoVisible ? 0 : 8)
                Spacer()
                ZStack {
                    HStack(spacing: 10) { Image(systemName: "apple.logo").font(.title3); Text("Continue with Apple").font(.headline.weight(.regular)) }.foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 54).modifier(LiquidGlassSurface(shape: .capsule))
                    SignInWithAppleButton(.continue) { request in
                        let nonce = UUID().uuidString + UUID().uuidString
                        appleNonce = nonce
                        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                  let data = credential.identityToken,
                                  let token = String(data: data, encoding: .utf8), let nonce = appleNonce else {
                                auth.errorMessage = "Apple didn’t return a valid sign-in token. Please try again."
                                return
                            }
                            appleNonce = nil
                            Task { await auth.signInWithApple(idToken: token, nonce: nonce) }
                        case .failure(let error):
                            appleNonce = nil
                            if (error as NSError).code != ASAuthorizationError.canceled.rawValue { auth.errorMessage = error.localizedDescription }
                        }
                    }
                    .signInWithAppleButtonStyle(.black).opacity(0.01).frame(height: 54).clipShape(Capsule())
                }

                emailForm
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .padding(28)
            .onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.15)) { logoVisible = true } }
        }
        .sheet(isPresented: Binding(get: { auth.needsPasswordReset }, set: { if !$0 { auth.cancelPasswordReset() } })) {
            PasswordResetSheet()
        }
    }

    private var emailForm: some View {
        VStack(spacing: 12) {
            ZStack {
                switch emailStep {
                case .email:
                    TextField("", text: $email, prompt: Text("Email address").foregroundStyle(.white.opacity(0.72)))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .padding(.horizontal, 16)
                        .foregroundColor(.white)
                        .tint(.white)
                case .password:
                    SecureField("", text: $password, prompt: Text("Password").foregroundStyle(.white.opacity(0.72)))
                        .textContentType(emailMode == .signUp ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .padding(.horizontal, 16)
                        .foregroundColor(.white)
                        .tint(.white)
                case .confirmation:
                    SecureField("", text: $passwordConfirmation, prompt: Text("Confirm password").foregroundStyle(.white.opacity(0.72)))
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .passwordConfirmation)
                        .padding(.horizontal, 16)
                        .foregroundColor(.white)
                        .tint(.white)
                }
            }
            .frame(height: 54)
            .modifier(LiquidGlassSurface(shape: .capsule))

            if let message = auth.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
            }

            if let message = auth.confirmationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
            }

            Button {
                Task {
                    if emailStep == .email {
                        selectEmailMode(emailMode)
                    } else if emailStep == .password {
                        guard password.count >= 6 else {
                            auth.errorMessage = "Your password must be at least 6 characters."
                            return
                        }
                        if emailMode == .signUp {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                emailStep = .confirmation
                                focusedField = .passwordConfirmation
                            }
                        } else {
                            _ = await auth.signIn(email: email, password: password)
                        }
                    } else {
                        guard passwordConfirmation.count >= 6 else {
                            auth.errorMessage = "Your password must be at least 6 characters."
                            return
                        }
                        guard password == passwordConfirmation else {
                            auth.errorMessage = "Those passwords don’t match."
                            return
                        }
                        let success = await auth.signUp(email: email, password: password)
                        if !success, emailMode == .signUp, auth.confirmationMessage != nil {
                            // Supabase requires email confirmation before issuing a session.
                            // Return to the email step so the user can switch directly to sign in.
                            withAnimation(.easeInOut(duration: 0.25)) {
                                emailMode = .signIn
                                emailStep = .email
                                password = ""
                                passwordConfirmation = ""
                                focusedField = .email
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if auth.isLoading { ProgressView().tint(.black) }
                    Text(buttonTitle)
                }
                .font(.headline.weight(.regular))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(.white, in: Capsule())
            .disabled(auth.isLoading)

            if emailStep == .email {
                HStack(spacing: 5) {
                    Text(emailMode == .signUp ? "Already a member?" : "New here?")
                    Button(emailMode == .signUp ? "Sign in" : "Sign up") {
                        emailMode = emailMode == .signUp ? .signIn : .signUp
                        auth.errorMessage = nil
                        auth.confirmationMessage = nil
                    }
                }
                .font(.subheadline.weight(.regular))
                .foregroundStyle(.white)
            }
            if emailMode == .signIn {
                Button("Forgot password?") { Task { await auth.requestPasswordReset(email: email) } }
                    .font(.caption).foregroundStyle(.white).disabled(auth.isLoading)
            }
        }
        .onAppear { focusedField = .email }
    }

    private func selectEmailMode(_ mode: EmailMode) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            auth.errorMessage = "Enter a valid email address."
            return
        }

        email = cleanEmail
        emailMode = mode
        auth.errorMessage = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            emailStep = .password
            focusedField = .password
        }
    }

    private var buttonTitle: String {
        switch emailStep {
        case .email: return "Continue"
        case .password: return emailMode == .signUp ? "Continue" : "Sign in"
        case .confirmation: return "Create account"
        }
    }
}

private struct PasswordResetSheet: View {
    @EnvironmentObject private var auth: AuthService
    @State private var password = ""
    @State private var confirmation = ""
    var body: some View {
        NavigationStack {
            Form {
                SecureField("New password", text: $password).textContentType(.newPassword)
                SecureField("Confirm new password", text: $confirmation).textContentType(.newPassword)
                if let error = auth.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                Button("Update password") { Task { await auth.finishPasswordReset(password: password) } }
                    .disabled(auth.isLoading || password.count < 8 || password != confirmation)
                Text("Use at least 8 characters. Both passwords must match.").font(.caption).foregroundStyle(.secondary)
            }.scrollContentBackground(.hidden).background(HydrationTheme.canvas.ignoresSafeArea())
                .navigationTitle("New password").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { auth.cancelPasswordReset() }.disabled(auth.isLoading)
                } }
        }.interactiveDismissDisabled(auth.isLoading).tint(.black)
    }
}

private struct LoopingVideoBackground: UIViewRepresentable {
    @StateObject private var controller = LoopingVideoController()

    func makeUIView(context: Context) -> VideoBackgroundView {
        let view = VideoBackgroundView()
        view.playerLayer.player = controller.player
        view.playerLayer.videoGravity = .resizeAspectFill
        controller.start()
        return view
    }

    func updateUIView(_ view: VideoBackgroundView, context: Context) {
        view.playerLayer.player = controller.player
    }
}

private final class VideoBackgroundView: UIView {
    let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

private final class LoopingVideoController: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init() {
        // Xcode copies resources into the app bundle root even when they live in
        // a source folder, so look up the bundled file without a subdirectory.
        guard let url = Bundle.main.url(forResource: "login-background", withExtension: "mp4") else {
            return
        }

        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.isMuted = true
        player.actionAtItemEnd = .none
    }

    func start() {
        player.play()
    }
}

struct BundledImage: View {
    let name: String
    var directory: String? = "DrinkIcons"
    var body: some View {
        Group {
            if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: directory), let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let path = Bundle.main.path(forResource: name, ofType: "png"), let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let image = UIImage(named: name) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.clear
            }
        }
        .clipped()
    }
}


struct RootView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var selection = 0
    @State private var showingPhotoLog = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView().tag(0).toolbar(.hidden, for: .tabBar)
            InsightsView().tag(1).toolbar(.hidden, for: .tabBar)
            ProfileView().tag(3).toolbar(.hidden, for: .tabBar)
        }
        .tint(.black)
        .onAppear { store.publishWidgetData() }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            CompactNavigation(selection: $selection, isPro: subscriptions.isPro) { showingPhotoLog = true }
        }
        .fullScreenCover(isPresented: $showingPhotoLog) {
            PhotoLogSheet(onLogged: { selection = 0 })
        }
    }
}

private struct CompactNavigation: View {
    @Binding var selection: Int
    let isPro: Bool
    let openPhotoLog: () -> Void
    var body: some View {
        HStack(spacing: 2) {
            navButton("Home", "house", 0)
            navButton("Insights", "chart.bar.xaxis", 1)
            if isPro {
                Button(action: openPhotoLog) {
                    VStack(spacing: 3) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .light))
                        Text("Scan").font(.system(size: 10, weight: .regular, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan water with a photo")
            }
            navButton("Profile", "person.crop.circle", 3)
        }
        .padding(.horizontal, 6)
        .frame(height: 60)
        .modifier(LiquidGlassNavigation())
        .frame(maxWidth: 340)
        .padding(.horizontal, 32).padding(.bottom, 6)
        .frame(maxWidth: .infinity)
    }
    private func navButton(_ title: String, _ icon: String, _ tag: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { selection = tag } } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .light))
                    .environment(\.symbolVariants, .none)
                Text(title).font(.system(size: 10, weight: .regular, design: .rounded))
            }
            .foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 48)
            .background(selection == tag ? Color.black.opacity(0.06) : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tag ? .isSelected : [])
    }
}

private struct LiquidGlassNavigation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
        }
    }
}

struct AddWaterSheet: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = "8"
    private var amount: Int? {
        return WaterVolume.milliliters(amountText)
    }
    var body: some View {
        VStack(spacing: 24) {
            Text("Enter amount").font(.title2.weight(.regular))
            HStack(spacing: 20) {
                Button { adjust(-1) } label: {
                    Image(systemName: "minus").frame(width: 48, height: 48)
                        .modifier(LiquidGlassSurface(shape: .capsule))
                }.disabled((amount ?? 0) <= 12).accessibilityLabel("Decrease by one fluid ounce")
                VStack(spacing: 4) {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad).multilineTextAlignment(.center)
                        .font(.system(size: 38, weight: .regular, design: .rounded))
                        .accessibilityLabel("Water amount in fluid ounces")
                    Text("fl oz").font(.subheadline).foregroundStyle(.secondary)
                }
                Button { adjust(1) } label: {
                    Image(systemName: "plus").frame(width: 48, height: 48)
                        .modifier(LiquidGlassSurface(shape: .capsule))
                }.disabled((amount ?? 0) >= 7567).accessibilityLabel("Increase by one fluid ounce")
            }.buttonStyle(.plain)
            Text("Adjust by 1 fl oz, or tap the number to type.")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                guard let amount else { return }
                store.addWater(amount); dismiss()
            } label: {
                Text("Log water").frame(maxWidth: .infinity).frame(height: 46)
                    .background(Color.blue.opacity(0.07), in: Capsule())
                    .modifier(LiquidGlassSurface(shape: .capsule))
            }.buttonStyle(.plain).disabled(amount == nil)
        }.padding(24)
            .presentationDetents([.height(310), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground { HydrationTheme.canvas }
    }
    private func adjust(_ delta: Int) {
        amountText = String(min(255.9, max(0.4, (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 8) + Double(delta))))
    }
}

struct DrinkIcon: View {
    let name: String
    var tint: Color? = nil
    var starter = false
    private var resourceName: String { starter ? BottleCatalog.starterAsset(name) : name }
    var body: some View {
        Group {
            if let path = Bundle.main.path(forResource: resourceName, ofType: "png", inDirectory: "DrinkIcons"), let image = UIImage(contentsOfFile: path) {
                rendered(Image(uiImage: image))
            } else if let path = Bundle.main.path(forResource: resourceName, ofType: "png"), let image = UIImage(contentsOfFile: path) {
                rendered(Image(uiImage: image))
            } else if let image = UIImage(named: resourceName) {
                rendered(Image(uiImage: image))
            } else {
                Image(systemName: "drop.fill").resizable().scaledToFit().padding(24).foregroundStyle(.blue)
            }
        }
    }

    private func rendered(_ image: Image) -> some View {
        // Preserve the supplied artwork exactly: original for onboarding, clear for collection.
        image.resizable().scaledToFit()
    }
}
