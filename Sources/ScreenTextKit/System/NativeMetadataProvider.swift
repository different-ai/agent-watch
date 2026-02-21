import AppKit
import ApplicationServices
import Foundation

public final class NativeMetadataProvider {
    public init() {}

    public func currentMetadata() -> CaptureMetadata {
        let frontmost = NSWorkspace.shared.frontmostApplication
        return CaptureMetadata(
            appName: frontmost?.localizedName ?? "Unknown",
            windowTitle: focusedWindowTitle(),
            bundleID: frontmost?.bundleIdentifier,
            displayID: "main"
        )
    }

    private func focusedWindowTitle() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        guard
            let appElement = copyElementAttribute(element: systemWide, attribute: kAXFocusedApplicationAttribute),
            let windowElement = copyElementAttribute(element: appElement, attribute: kAXFocusedWindowAttribute)
        else {
            return nil
        }

        return copyStringAttribute(element: windowElement, attribute: kAXTitleAttribute)
    }

    private func copyElementAttribute(element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value else {
            return nil
        }

        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func copyStringAttribute(element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value else {
            return nil
        }

        if let text = value as? String {
            return text
        }

        if let attributed = value as? NSAttributedString {
            return attributed.string
        }

        return nil
    }
}
