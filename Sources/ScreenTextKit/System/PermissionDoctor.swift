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

public enum PermissionDoctor {
    public static func snapshot() -> PermissionSnapshot {
        let accessibility = AXIsProcessTrusted()
        let screenRecording = CGDisplayCreateImage(CGMainDisplayID()) != nil
        return PermissionSnapshot(accessibilityGranted: accessibility, screenRecordingGranted: screenRecording)
    }
}
