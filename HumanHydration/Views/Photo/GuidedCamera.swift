import SwiftUI
import Combine
import AVFoundation
import CoreMotion
import UIKit

/// A single still capture after the user starts a scan and holds the device steady.
/// Motion measures camera steadiness, not vessel recognition or water volume.
struct GuidedCamera: View {
    let onComplete: (UIImage?) -> Void
    @StateObject private var camera = ScannerCamera()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button { onComplete(nil) } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }.accessibilityLabel("Close scanner")
                    Spacer()
                    Text("Scan water").font(.headline)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 32)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [18, 10]))
                    .frame(maxWidth: 290).frame(height: 330)
                    .overlay {
                        if camera.armed && !reduceMotion {
                            TimelineView(.animation) { context in
                                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2
                                Rectangle().fill(.white.opacity(0.6)).frame(height: 2)
                                    .padding(.horizontal, 20)
                                    .offset(y: CGFloat(sin(phase * .pi * 2)) * 135)
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if camera.armed {
                            ProgressView(value: camera.steadyProgress).tint(.white)
                                .padding(24)
                        }
                    }
                    .accessibilityHidden(true)
                Text(camera.message).font(.title3).multilineTextAlignment(.center)
                Spacer()
                if !camera.armed {
                    Button(camera.ready ? "Start scan" : "Preparing camera…") { camera.arm() }
                        .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
                        .disabled(!camera.ready)
                } else {
                    Button("Capture now") { camera.capture() }
                        .buttonStyle(.bordered).disabled(camera.capturing)
                    Text("Auto-captures when steady").font(.caption)
                }
            }.padding(24).foregroundStyle(.white)
        }
        .onAppear { camera.onPhoto = onComplete; camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { camera.start() } else { camera.stop() }
        }
    }
}

private final class ScannerCamera: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "human.camera")
    private let motion = CMMotionManager()
    private var configured = false
    private var steadySince: TimeInterval?
    @Published var ready = false
    @Published var armed = false
    @Published var capturing = false
    @Published var steadyProgress = 0.0
    @Published var message = "Point at your glass or bottle"
    var onPhoto: ((UIImage?) -> Void)?

    func start() {
        queue.async { [self] in
            if !configured {
                session.beginConfiguration()
                session.sessionPreset = .photo
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input), session.canAddOutput(output) else {
                    session.commitConfiguration()
                    DispatchQueue.main.async { self.message = "Camera unavailable. Close and try again." }
                    return
                }
                session.addInput(input); session.addOutput(output)
                if (try? device.lockForConfiguration()) != nil {
                    if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                    if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                    device.unlockForConfiguration()
                }
                session.commitConfiguration()
                configured = true
            }
            if !session.isRunning { session.startRunning() }
            DispatchQueue.main.async { self.ready = self.session.isRunning }
        }
    }

    func arm() {
        guard ready, !capturing else { return }
        armed = true; steadySince = nil; steadyProgress = 0
        message = "Hold steady"
        guard motion.isDeviceMotionAvailable else {
            message = "Frame your drink, then tap Capture now"
            return
        }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let self, self.armed, !self.capturing, let sample else { return }
            let r = sample.rotationRate, a = sample.userAcceleration
            let still = abs(r.x) + abs(r.y) + abs(r.z) < 0.12 && abs(a.x) + abs(a.y) + abs(a.z) < 0.08
            if !still { self.steadySince = nil; self.steadyProgress = 0; return }
            if self.steadySince == nil { self.steadySince = sample.timestamp }
            self.steadyProgress = min(1, (sample.timestamp - (self.steadySince ?? sample.timestamp)) / 1.6)
            if self.steadyProgress >= 1 { self.capture() }
        }
    }

    func capture() {
        guard ready, armed, !capturing else { return }
        capturing = true; motion.stopDeviceMotionUpdates(); message = "Capturing…"
        // Snapshot orientation on the UI thread before scheduling camera work.
        let orientation = UIDevice.current.orientation
        queue.async { [self] in
            guard session.isRunning else {
                DispatchQueue.main.async { self.capturing = false; self.armed = false; self.message = "Camera paused. Start another scan." }
                return
            }
            if let connection = output.connection(with: .video) {
                let angle: CGFloat
                switch orientation {
                case .landscapeLeft: angle = 0
                case .landscapeRight: angle = 180
                case .portraitUpsideDown: angle = 270
                default: angle = 90
                }
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            }
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = error == nil ? photo.fileDataRepresentation().flatMap { UIImage(data: $0) } : nil
        DispatchQueue.main.async {
            self.capturing = false; self.armed = false
            if let image { self.onPhoto?(image) }
            else { self.message = "Couldn’t capture. Start another scan." }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates(); armed = false; ready = false; steadySince = nil; steadyProgress = 0
        queue.async { [self] in if session.isRunning { session.stopRunning() } }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) { }
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            guard let connection = preview.connection else { return }
            let angle: CGFloat
            switch window?.windowScene?.interfaceOrientation {
            case .landscapeLeft: angle = 180
            case .landscapeRight: angle = 0
            case .portraitUpsideDown: angle = 270
            default: angle = 90
            }
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        }
    }
}
