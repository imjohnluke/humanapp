import SwiftUI
import AVFoundation
import UIKit

struct PhotoLogSheet: View {
    var onLogged: () -> Void = {}
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @State private var checkingAccess = true
    @State private var image: UIImage?
    @State private var jpeg: Data?
    @State private var showingCamera = false
    @State private var drinkName = "My glass"
    @State private var capacityText = ""
    @State private var savedDrink = false
    @State private var quarters = 4
    @State private var estimate: PhotoEstimate?
    @State private var amountText = ""
    @State private var isBusy = false
    @State private var didLog = false
    @State private var errorMessage: String?
    @State private var work: Task<Void, Never>?
    private let service = PhotoEstimateService()
    private var logAmount: Int? {
        return WaterVolume.milliliters(amountText)
    }

    var body: some View {
        ZStack {
            if showingCamera {
                GuidedCamera { photo in
                    guard let photo else { dismiss(); return }
                    prepare(photo)
                    showingCamera = false
                    if jpeg != nil { work = Task { await analyze() } }
                }
            } else if checkingAccess {
                Color.black.ignoresSafeArea()
                ProgressView().tint(.white)
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            photoFlow
                            if let errorMessage {
                                Text(errorMessage).font(.subheadline).foregroundStyle(.secondary)
                                    .accessibilityLabel("Error: \(errorMessage)")
                            }
                        }.padding(24)
                    }
                    .background(HydrationTheme.canvas.ignoresSafeArea())
                    .navigationTitle("Review water").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
                }
            }
        }
        .task {
            await openCamera()
            checkingAccess = false
        }
        .onDisappear { work?.cancel() }
    }

    private var photoFlow: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                    .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        if isBusy {
                            ZStack {
                                Color.black.opacity(0.3)
                                VStack(spacing: 12) {
                                    ProgressView().tint(.white)
                                    Text("Estimating water…").foregroundStyle(.white)
                                }
                            }.clipShape(RoundedRectangle(cornerRadius: 22))
                        }
                    }
            }
            if let estimate {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Estimated water").font(.headline.weight(.regular))
                    Text(estimate.container).font(.subheadline)
                    Text("\(estimate.confidence.capitalized) confidence · Approximate")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(estimate.explanation).font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Fluid ounces", text: $amountText).keyboardType(.decimalPad)
                            .font(.system(size: 42, weight: .regular, design: .rounded))
                            .accessibilityLabel("Water amount in fluid ounces")
                        Text("fl oz").foregroundStyle(.secondary)
                    }
                    Text("How much of this water did you drink?").font(.subheadline)
                    Picker("Portion consumed", selection: $quarters) {
                        Text("¼").tag(1); Text("½").tag(2); Text("All").tag(4)
                    }.pickerStyle(.segmented)
                    .onChange(of: quarters) { _, value in
                        if let amount = estimate.amountML { amountText = WaterVolume.input(max(10, Int((Double(amount) * Double(value) / 4).rounded()))) }
                    }
                    Text("The estimate shows water in the container. Adjust this to the amount you actually drank.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button("Retake") { work = Task { await openCamera() } }
                            .frame(maxWidth: .infinity).buttonStyle(.bordered)
                        Button {
                            guard !didLog, let amount = logAmount else { return }
                            didLog = true
                            store.addWater(amount)
                            onLogged()
                            dismiss()
                        } label: {
                            Text("Submit").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).tint(.black)
                            .disabled(logAmount == nil || didLog)
                    }
                    if logAmount == nil { Text("Enter an amount between 0.4 and 255.9 fl oz.").font(.caption) }
                    Divider()
                    Text("Use this glass or bottle again").font(.headline.weight(.regular))
                    TextField("Drink name", text: $drinkName).textFieldStyle(.roundedBorder)
                    HStack {
                        TextField("Full capacity", text: $capacityText).keyboardType(.decimalPad)
                        Text("fl oz full").foregroundStyle(.secondary)
                    }
                    Text("This is the estimated full capacity, separate from water remaining or drunk. Check the label or adjust before saving.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(savedDrink ? "Saved to my drinks" : "Save my drink") {
                        guard let capacity = WaterVolume.milliliters(capacityText, minimum: 40) else { return }
                        store.saveDrink(name: drinkName, capacityML: capacity, isEstimate: true)
                        savedDrink = true
                    }.disabled(savedDrink || drinkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || WaterVolume.milliliters(capacityText, minimum: 40) == nil)
                }.padding(20).modifier(LiquidGlassSurface(shape: .rounded(24)))
            } else if !isBusy {
                HStack(spacing: 12) {
                    Button("Retake") { work = Task { await openCamera() } }
                        .frame(maxWidth: .infinity).buttonStyle(.bordered)
                    if jpeg != nil {
                        Button("Retry estimate") { work = Task { await analyze() } }
                            .frame(maxWidth: .infinity).buttonStyle(.borderedProminent).tint(.black)
                    }
                }
            }
            Button("Log manually instead") { dismiss() }.font(.subheadline)
        }
    }

    @MainActor private func analyze() async {
        guard !isBusy, let jpeg else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            let userID = auth.user?.id
            let token = try await auth.accessTokenForAPI()
            let result = try await service.estimate(jpeg: jpeg, token: token)
            try Task.checkCancellation()
            guard auth.user?.id == userID else { throw CancellationError() }
            estimate = result
            amountText = WaterVolume.input(result.amountML!)
            capacityText = result.capacityML.map(WaterVolume.input) ?? ""
            drinkName = result.container.lowercased().contains("bottle") ? "My bottle" : "My glass"
        } catch is CancellationError { }
        catch {
            errorMessage = (error as? PhotoEstimateError)?.errorDescription ?? "The estimate didn’t finish. Please check your connection and try again."
        }
    }

    @MainActor private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "A camera isn’t available on this device. You can log water manually."; return
        }
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
        default: allowed = false
        }
        guard !Task.isCancelled else { return }
        if allowed { showingCamera = true }
        else { errorMessage = "Enable camera access in iPhone Settings to scan water, or log manually." }
    }

    @MainActor private func prepare(_ photo: UIImage) {
        resetEstimate()
        let scale = min(1280 / max(photo.size.width, photo.size.height), 1)
        let size = CGSize(width: max(1, photo.size.width * scale), height: max(1, photo.size.height * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        // Re-render to normalize rotation, reduce size and remove source metadata (including GPS).
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            photo.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = normalized.jpegData(compressionQuality: 0.8), data.count <= 2 * 1024 * 1024 else {
            image = nil; jpeg = nil; errorMessage = "This photo is too large. Please take another."; return
        }
        image = normalized; jpeg = data
    }
    private func resetEstimate() { estimate = nil; amountText = ""; didLog = false; errorMessage = nil; savedDrink = false; quarters = 4 }
}
