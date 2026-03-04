import Foundation

public final class NativeTextExtractor: TextExtractor {
    private let metadataProvider: NativeMetadataProvider
    private let accessibilityExtractor: AccessibilityTextExtractor
    private let ocrExtractor: OCRTextExtractor
    private let minimumAccessibilityChars: Int
    private let ocrEnabled: Bool
    private let forceOCR: Bool

    public init(
        metadataProvider: NativeMetadataProvider = NativeMetadataProvider(),
        accessibilityExtractor: AccessibilityTextExtractor = AccessibilityTextExtractor(),
        ocrExtractor: OCRTextExtractor = OCRTextExtractor(),
        minimumAccessibilityChars: Int,
        ocrEnabled: Bool,
        forceOCR: Bool = false
    ) {
        self.metadataProvider = metadataProvider
        self.accessibilityExtractor = accessibilityExtractor
        self.ocrExtractor = ocrExtractor
        self.minimumAccessibilityChars = minimumAccessibilityChars
        self.ocrEnabled = ocrEnabled
        self.forceOCR = forceOCR
    }

    public func extract() throws -> ExtractedText? {
        let metadata = metadataProvider.currentMetadata()

        let accessibilityText = accessibilityExtractor.extractText()
        let hasGoodAccessibility = (accessibilityText?.count ?? 0) >= minimumAccessibilityChars

        // Always run OCR too (if enabled) and keep the longer result
        var ocrText: String? = nil
        if ocrEnabled {
            ocrText = try ocrExtractor.extractText()
        }

        let accLen = accessibilityText?.count ?? 0
        let ocrLen = ocrText?.count ?? 0

        // Return whichever extracted more text
        if ocrLen > accLen && ocrLen > 0 {
            return ExtractedText(text: ocrText!, source: .ocr, metadata: metadata)
        } else if accLen > 0 && hasGoodAccessibility {
            return ExtractedText(text: accessibilityText!, source: .accessibility, metadata: metadata)
        } else if ocrLen > 0 {
            return ExtractedText(text: ocrText!, source: .ocr, metadata: metadata)
        }

        return nil
    }
}
