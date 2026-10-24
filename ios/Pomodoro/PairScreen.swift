import AVFoundation
import PomodoroCore
import SwiftUI

/// The camera, for the QR on the Mac only. The permission is asked here, the
/// first time the scanner opens; without it the screen says why it needs it.
struct PairScreen: View {
    let onLink: (PairLink) -> Void

    @State private var access = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("On the Mac: Pomodoro → Settings → Devices → Pair a Phone. Then point the camera at the code.")
            ZStack {
                Theme.box
                if access == .authorized {
                    QRScanner { text in
                        guard !done, let link = PairLink(link: text) else { return }
                        done = true
                        onLink(link)
                    }
                } else {
                    Text("Pomodoro needs the camera only to read this code.")
                        .foregroundStyle(Theme.secondary)
                        .padding(24)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            if access == .denied || access == .restricted {
                // iOS asks only once; after a refusal only Settings can allow it.
                Button("Allow the camera") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Spacer()
        }
        .padding(16)
        .font(Theme.labelFont)
        .foregroundStyle(Theme.label)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Pair with Mac")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if access == .notDetermined { _ = await AVCaptureDevice.requestAccess(for: .video) }
            access = AVCaptureDevice.authorizationStatus(for: .video)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Back from Settings.
            access = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}

private struct QRScanner: UIViewRepresentable {
    let onCode: (String) -> Void

    func makeUIView(context: Context) -> ScannerView {
        let view = ScannerView()
        view.onCode = onCode
        view.start()
        return view
    }

    func updateUIView(_ view: ScannerView, context: Context) {
        view.onCode = onCode
    }

    static func dismantleUIView(_ view: ScannerView, coordinator: ()) {
        view.stop()
    }
}

private final class ScannerView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.nikolaev.pomodoro.camera")

    func start() {
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = layer as! AVCaptureVideoPreviewLayer
        preview.session = session
        preview.videoGravity = .resizeAspectFill
        // startRunning blocks until the camera is up: not on the main thread.
        nonisolated(unsafe) let session = session
        queue.async { session.startRunning() }
    }

    func stop() {
        nonisolated(unsafe) let session = session
        queue.async { session.stopRunning() }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let text = objects.lazy.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }.first
        MainActor.assumeIsolated {
            if let text { onCode?(text) }
        }
    }
}
