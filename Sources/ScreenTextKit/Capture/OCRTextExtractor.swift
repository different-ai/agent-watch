import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Vision

public final class OCRTextExtractor {
    private let minimumTextHeight: Float
    private let recognitionLevel: VNRequestTextRecognitionLevel

    public init(minimumTextHeight: Float = 0.002, recognitionLevel: VNRequestTextRecognitionLevel = .accurate) {
        self.minimumTextHeight = minimumTextHeight
        self.recognitionLevel = recognitionLevel
    }

    public func extractText() throws -> String? {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            return nil
        }

        // Run OCR on both original and inverted image, keep the one with more text.
        // Dark UIs (WhatsApp, Slack, etc.) yield much more text when colors are inverted.
        let originalText = try extractText(from: image)
        let invertedText: String?
        if let inverted = invertColors(image) {
            invertedText = try extractText(from: inverted)
        } else {
            invertedText = nil
        }

        let orig = originalText ?? ""
        let inv = invertedText ?? ""

        if orig.isEmpty && inv.isEmpty {
            return nil
        }

        return inv.count > orig.count ? inv : orig
    }

    public func extractText(fromImageURL imageURL: URL) throws -> String? {
        guard
            let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        return try extractText(from: image)
    }

    public func extractText(from image: CGImage) throws -> String? {

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.minimumTextHeight = minimumTextHeight
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? [])
            .compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return nil
        }

        return lines.joined(separator: "\n")
    }

    /// Invert image colors using CoreImage — turns dark UIs light for better OCR
    private func invertColors(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let output = filter.outputImage else { return nil }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(output, from: output.extent)
    }
}
