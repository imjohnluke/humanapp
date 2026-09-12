import SwiftUI
import UIKit
import AuthenticationServices
import AVFoundation

@main
struct HumanHydrationApp: App {
    @StateObject private var store = HydrationStore()
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environmentObject(store)
                .environmentObject(auth)
        }
    }
}

private struct LaunchView: View {
    @EnvironmentObject private var auth: AuthService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("isSignedIn") private var isSignedIn = false
    var body: some View {
        if !isSignedIn && !auth.isAuthenticated { SignInView() }
        else if !hasCompletedOnboarding { OnboardingView() }
        else { RootView() }
    }
}

private struct SignInView: View {
    @EnvironmentObject private var auth: AuthService
    @AppStorage("isSignedIn") private var isSignedIn = false
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .opacity(logoVisible ? 1 : 0)
                    .offset(y: logoVisible ? 0 : 8)
                Spacer()
                ZStack {
                    HStack(spacing: 10) { Image(systemName: "apple.logo").font(.title3); Text("Continue with Apple").font(.headline) }.foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 54).modifier(LiquidGlassSurface(shape: .capsule))
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        if case .success(let authorization) = result, authorization.credential is ASAuthorizationAppleIDCredential { isSignedIn = true }
                    }
                    .signInWithAppleButtonStyle(.black).opacity(0.01).frame(height: 54).clipShape(Capsule())
                }

                emailForm
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .padding(28)
            .onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.15)) { logoVisible = true } }
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
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
            }

            if let message = auth.confirmationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
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
                            let success = await auth.signIn(email: email, password: password)
                            if success { isSignedIn = true }
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
                        if success {
                            isSignedIn = true
                        } else if emailMode == .signUp, auth.confirmationMessage != nil {
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
                .font(.headline)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
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
            } else if let image = UIImage(named: name) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.clear
            }
        }
        .clipped()
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step = 0
    @State private var name = ""
    @State private var goal: Double = 2400
    var body: some View {
        ZStack {
            HydrationTheme.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                if step == 0 {
                    Text("What should we call you?").font(.largeTitle.bold())
                    Text("Your name will appear on your Human profile.").font(.title3).foregroundStyle(.secondary)
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .padding(.horizontal, 18)
                        .frame(height: 56)
                        .modifier(LiquidGlassSurface(shape: .rounded(20)))
                } else {
                    Text("Let’s set your goal").font(.largeTitle.bold())
                    Text("Choose a daily target that feels right for you. You can change it anytime.").font(.title3).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Daily hydration goal").font(.headline)
                        Text("\(Int(goal)) ml").font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(.blue)
                        Slider(value: $goal, in: 1000...5000, step: 100).tint(.blue)
                    }.padding(22).modifier(LiquidGlassSurface(shape: .rounded(24)))
                }
                Spacer()
                Button {
                    if step == 0 {
                        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanName.isEmpty else { return }
                        store.displayName = cleanName
                        withAnimation(.easeInOut(duration: 0.25)) { step = 1 }
                    } else {
                        store.dailyGoalML = Int(goal)
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text("Continue").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
            }.padding(28)
        }
    }
}

struct RootView: View {
    @State private var showingAddWater = false
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            TodayView().tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            InsightsView().tabItem { Label("Progress", systemImage: "chart.bar.fill") }.tag(1)
            Color.clear.tabItem { Label("Add", systemImage: "plus") }.tag(2)
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(3)
        }
        .tint(.black)
        .onChange(of: selection) { _, newValue in
            if newValue == 2 {
                showingAddWater = true
                selection = 0
            }
        }
        .sheet(isPresented: $showingAddWater) { AddWaterSheet() }
    }
}

private struct CompactNavigation: View {
    @Binding var selection: Int
    let addWater: () -> Void
    var body: some View {
        HStack(spacing: 2) {
            navButton("Home", "house.fill", 0)
            navButton("Progress", "chart.bar.fill", 1)
            navButton("Settings", "gearshape.fill", 2)
            Button(action: addWater) {
                VStack(spacing: 3) { Image(systemName: "plus").font(.system(size: 18, weight: .medium)); Text("Add").font(.caption2) }
                    .foregroundStyle(.black).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .modifier(LiquidGlassNavigation())
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.13), radius: 14, y: 5)
        .padding(.horizontal, 14).padding(.bottom, 8)
    }
    private func navButton(_ title: String, _ icon: String, _ tag: Int) -> some View {
        Button { selection = tag } label: {
            VStack(spacing: 3) { Image(systemName: icon).font(.system(size: 18, weight: .medium)); Text(title).font(.caption2.weight(selection == tag ? .semibold : .regular)) }
                .foregroundStyle(.black).frame(maxWidth: .infinity)
        }
    }
}

private struct LiquidGlassNavigation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(.white.opacity(0.18)).interactive(), in: .rect(cornerRadius: 24))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .background(Color(red: 0.88, green: 0.95, blue: 1.0).opacity(0.58), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.8), lineWidth: 1))
        }
    }
}

private struct AddWaterSheet: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 250
    private let maximumAmount = 7_570.0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule().fill(.secondary.opacity(0.25)).frame(width: 38, height: 5).frame(maxWidth: .infinity)
            Text("Add water").font(.title2.bold())
            VStack(spacing: 8) {
                DrinkIcon(name: amountAssetName)
                    .frame(width: 82, height: 108)
                Text("\(Int(amount)) ml").font(.system(size: 42, weight: .bold, design: .rounded))
                Text("about \(Int(amount * 0.033814)) fl oz").font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity)
            VStack(spacing: 6) {
                Slider(value: $amount, in: 50...maximumAmount, step: 10).tint(.blue)
                HStack { Text("50 ml"); Spacer(); Text("7,570 ml · 2 gal") }.font(.caption).foregroundStyle(.secondary)
            }
            Button {
                store.addWater(Int(amount)); dismiss()
            } label: {
                Text("Log water").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
            }.buttonStyle(.borderedProminent).tint(.black)
            Spacer()
        }.padding(24).presentationDetents([.medium]).presentationDragIndicator(.hidden)
    }

    private var amountAssetName: String {
        switch amount {
        case 0..<400: return "glass"
        case 400..<700: return "bottle"
        case 700..<1200: return "gatorade"
        case 1200..<2000: return "stanley"
        default: return "gallon"
        }
    }
}

struct DrinkIcon: View {
    let name: String
    var tint: Color? = nil
    var body: some View {
        Group {
            if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: "DrinkIcons"), let image = UIImage(contentsOfFile: path) {
                rendered(Image(uiImage: image))
            } else if let image = UIImage(named: name) {
                rendered(Image(uiImage: image))
            } else {
                Image(systemName: "drop.fill").resizable().scaledToFit().padding(24).foregroundStyle(.blue)
            }
        }
    }

    private func rendered(_ image: Image) -> some View {
        image.resizable().scaledToFit().colorMultiply(tint ?? .white)
    }
}
