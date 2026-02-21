import CoreGraphics
import Foundation
import Vision

public final class OCRTextExtractor {
    private let minimumTextHeight: Float

    public init(minimumTextHeight: Float = 0.015) {
        self.minimumTextHeight = minimumTextHeight
    }

    public func extractText() throws -> String? {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.minimumTextHeight = minimumTextHeight
        request.usesLanguageCorrection = false

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
