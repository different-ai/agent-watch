import ApplicationServices
import Foundation

public final class AccessibilityTextExtractor {
    private let timeoutSeconds: TimeInterval
    private let maxDepth: Int
    private let maxChildrenPerNode: Int

    public init(timeoutSeconds: TimeInterval = 0.2, maxDepth: Int = 4, maxChildrenPerNode: Int = 30) {
        self.timeoutSeconds = timeoutSeconds
        self.maxDepth = maxDepth
        self.maxChildrenPerNode = maxChildrenPerNode
    }

    public func extractText() -> String? {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        let systemWide = AXUIElementCreateSystemWide()

        guard
            let appElement = copyElementAttribute(from: systemWide, attribute: kAXFocusedApplicationAttribute)
        else {
            return nil
        }

        var gathered = Set<String>()

        if let focusedElement = copyElementAttribute(from: appElement, attribute: kAXFocusedUIElementAttribute) {
            collectText(from: focusedElement, depth: 0, deadline: deadline, into: &gathered)
        }

        if let focusedWindow = copyElementAttribute(from: appElement, attribute: kAXFocusedWindowAttribute) {
            collectText(from: focusedWindow, depth: 0, deadline: deadline, into: &gathered)
        }

        let joined = gathered
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return joined.isEmpty ? nil : joined
    }

    private func collectText(from element: AXUIElement, depth: Int, deadline: Date, into output: inout Set<String>) {
        guard depth <= maxDepth else { return }
        guard Date() < deadline else { return }

        let attributes: [String] = [
            kAXValueAttribute,
            kAXTitleAttribute,
            kAXDescriptionAttribute,
            kAXSelectedTextAttribute,
        ]

        for attribute in attributes {
            if let value = copyAttributeValue(from: element, attribute: attribute),
               let text = flattenText(value),
               !text.isEmpty {
                output.insert(text)
            }
        }

        let childAttributes: [String] = [kAXVisibleChildrenAttribute, kAXChildrenAttribute]
        for childAttribute in childAttributes {
            let children = copyChildrenAttribute(from: element, attribute: childAttribute)
            var count = 0
            for child in children {
                if count >= maxChildrenPerNode { break }
                collectText(from: child, depth: depth + 1, deadline: deadline, into: &output)
                count += 1
            }
        }
    }

    private func flattenText(_ value: Any) -> String? {
        if let string = value as? String {
            return string
        }

        if let attributed = value as? NSAttributedString {
            return attributed.string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        if let strings = value as? [String] {
            return strings.joined(separator: " ")
        }

        if let array = value as? [Any] {
            let flattened = array.compactMap { flattenText($0) }
            if !flattened.isEmpty {
                return flattened.joined(separator: " ")
            }
        }

        return nil
    }

    private func copyElementAttribute(from element: AXUIElement, attribute: String) -> AXUIElement? {
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

    private func copyChildrenAttribute(from element: AXUIElement, attribute: String) -> [AXUIElement] {
        guard let values = copyAttributeValue(from: element, attribute: attribute) as? [Any] else {
            return []
        }

        var elements: [AXUIElement] = []
        for item in values {
            let cfObject = item as AnyObject
            guard CFGetTypeID(cfObject) == AXUIElementGetTypeID() else {
                continue
            }
            elements.append(unsafeDowncast(cfObject, to: AXUIElement.self))
        }

        return elements
    }

    private func copyAttributeValue(from element: AXUIElement, attribute: String) -> Any? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else {
            return nil
        }

        return value
    }
}
