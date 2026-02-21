import ApplicationServices
import CoreGraphics
import Foundation

public struct PermissionSnapshot: Sendable {
    public let accessibilityGranted: Bool
    public let screenRecordingGranted: Bool

    public init(accessibilityGranted: Bool, screenRecordingGranted: Bool) {
        self.accessibilityGranted = accessibilityGranted
        self.screenRecordingGranted = screenRecordingGranted
    }
}

public struct ScreenRecordingProbe: Sendable {
    public let granted: Bool
    public let width: Int
    public let height: Int
    public let byteCount: Int
    public let sampleHash: String?

    public init(granted: Bool, width: Int, height: Int, byteCount: Int, sampleHash: String?) {
        self.granted = granted
        self.width = width
        self.height = height
        self.byteCount = byteCount
        self.sampleHash = sampleHash
    }
}

public enum PermissionDoctor {
    public static func snapshot() -> PermissionSnapshot {
        let accessibility = AXIsProcessTrusted()
        let screenRecording = CGDisplayCreateImage(CGMainDisplayID()) != nil
        return PermissionSnapshot(accessibilityGranted: accessibility, screenRecordingGranted: screenRecording)
    }

    public static func probeScreenRecording() -> ScreenRecordingProbe {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            return ScreenRecordingProbe(granted: false, width: 0, height: 0, byteCount: 0, sampleHash: nil)
        }

        let width = image.width
        let height = image.height

        guard let dataRef = image.dataProvider?.data else {
            return ScreenRecordingProbe(granted: true, width: width, height: height, byteCount: 0, sampleHash: nil)
        }

        let byteCount = CFDataGetLength(dataRef)
        guard let pointer = CFDataGetBytePtr(dataRef), byteCount > 0 else {
            return ScreenRecordingProbe(granted: true, width: width, height: height, byteCount: byteCount, sampleHash: nil)
        }

        let sampleCount = min(byteCount, 4096)
        let sample = Data(bytes: pointer, count: sampleCount)
        let sampleHash = ScreenTextHasher.sha256(data: sample)

        return ScreenRecordingProbe(
            granted: true,
            width: width,
            height: height,
            byteCount: byteCount,
            sampleHash: sampleHash
        )
    }
}
