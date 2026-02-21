import Foundation

public final class NativeTextExtractor: TextExtractor {
    private let metadataProvider: NativeMetadataProvider
    private let accessibilityExtractor: AccessibilityTextExtractor
    private let ocrExtractor: OCRTextExtractor
    private let minimumAccessibilityChars: Int
    private let ocrEnabled: Bool

    public init(
        metadataProvider: NativeMetadataProvider = NativeMetadataProvider(),
        accessibilityExtractor: AccessibilityTextExtractor = AccessibilityTextExtractor(),
        ocrExtractor: OCRTextExtractor = OCRTextExtractor(),
        minimumAccessibilityChars: Int,
        ocrEnabled: Bool
    ) {
        self.metadataProvider = metadataProvider
        self.accessibilityExtractor = accessibilityExtractor
        self.ocrExtractor = ocrExtractor
        self.minimumAccessibilityChars = minimumAccessibilityChars
        self.ocrEnabled = ocrEnabled
    }

    public func extract() throws -> ExtractedText? {
        let metadata = metadataProvider.currentMetadata()

        if let accessibilityText = accessibilityExtractor.extractText(),
           accessibilityText.count >= minimumAccessibilityChars {
            return ExtractedText(text: accessibilityText, source: .accessibility, metadata: metadata)
        }

        guard ocrEnabled else {
            return nil
        }

        if let ocrText = try ocrExtractor.extractText(), !ocrText.isEmpty {
            return ExtractedText(text: ocrText, source: .ocr, metadata: metadata)
        }

        return nil
    }
}
