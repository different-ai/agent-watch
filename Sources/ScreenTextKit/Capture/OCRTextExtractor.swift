import CoreGraphics
import Foundation
import ImageIO
import Vision

public final class OCRTextExtractor {
    private let minimumTextHeight: Float
    private let recognitionLevel: VNRequestTextRecognitionLevel

    public init(minimumTextHeight: Float = 0.005, recognitionLevel: VNRequestTextRecognitionLevel = .accurate) {
        self.minimumTextHeight = minimumTextHeight
        self.recognitionLevel = recognitionLevel
    }

    public func extractText() throws -> String? {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            return nil
        }

        return try extractText(from: image)
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
}
