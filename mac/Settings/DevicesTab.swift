import CoreImage.CIFilterBuiltins
import SwiftUI
import PomodoroCore
import PomodoroConfig
import PomodoroUI

/// Paired phones, and the QR that pairs a new one (docs/SYNC.md).
struct DevicesTab: View {
    let sync: SyncServer
    let metrics: SettingsWindowConfig

    private static let qrSize: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            if let pairing = sync.pairing {
                pairingView(pairing)
            } else {
                deviceList
            }
            if let problem = sync.problem {
                hint(problem)
                    .padding(.top, metrics.sectionTopPadding)
            }
        }
    }

    private var deviceList: some View {
        VStack(spacing: 0) {
            if sync.devices.list.isEmpty {
                hint("Pair your phone to see and control this timer from Pomodoro on Android or iPhone, over your Wi-Fi.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, metrics.sectionBottomPadding)
            }
            ForEach(sync.devices.list) { device in
                FormRow("\(device.name) (\(DeviceKind.title(device.kind)))", metrics: metrics) {
                    if sync.connected.contains(device.id) { hint("Connected") }
                    Button("Remove") { sync.remove(device.id) }
                }
            }
            Button("Pair a Phone…") { sync.beginPairing() }
                .padding(.top, metrics.sectionTopPadding)
        }
    }

    private func pairingView(_ pairing: SyncServer.Pairing) -> some View {
        HStack(alignment: .top, spacing: metrics.boxPadding) {
            QRCode(text: pairing.link.link)
                .frame(width: Self.qrSize, height: Self.qrSize)
            VStack(alignment: .leading, spacing: metrics.rowSpacing) {
                Text("On the phone, open Pomodoro → Settings → Devices → Pair with Mac and point the camera here.")
                    .font(.system(size: metrics.labelSize))
                    .foregroundStyle(Color(hex: metrics.labelColor))
                    .fixedSize(horizontal: false, vertical: true)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, pairing.expiresAt.timeIntervalSince(context.date))
                    hint("Valid for \(TimeFormat.string(from: left)), for one phone.")
                }
                Button("Cancel") { sync.endPairing() }
                    .padding(.top, metrics.rowSpacing)
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Hint(text, metrics: metrics)
    }
}

/// Black on white whatever the theme: phone cameras read that best.
private struct QRCode: View {
    let text: String

    var body: some View {
        if let image = Self.image(text) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .padding(8)
                .background(Color.white)
        }
    }

    private static func image(_ text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: output.extent.size)
    }
}
