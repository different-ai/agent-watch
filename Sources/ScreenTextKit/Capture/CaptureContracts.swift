import Foundation

public protocol TextExtractor {
    func extract() throws -> ExtractedText?
}
