import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public final class FrameBufferStore {
    private let paths: ScreenTextPaths
    private let retentionSeconds: Int
    private let maxFrames: Int
    private let maxDimension: Int
    private let jpegQuality: Double

    public init(
        paths: ScreenTextPaths,
        retentionSeconds: Int,
        maxFrames: Int,
        maxDimension: Int = 1280,
        jpegQuality: Double = 0.45
    ) {
        self.paths = paths
        self.retentionSeconds = retentionSeconds
        self.maxFrames = maxFrames
        self.maxDimension = maxDimension
        self.jpegQuality = jpegQuality
    }

    @discardableResult
    public func captureFrame() throws -> URL? {
        try paths.ensureBaseDirectory()

        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            return nil
        }

        let scaledImage = downscaleIfNeeded(image, maxDimension: maxDimension) ?? image
        let filename = "frame-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        let url = paths.frameBufferDirectory.appendingPathComponent(filename, isDirectory: false)

        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality,
        ]

        CGImageDestinationAddImage(destination, scaledImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        try prune()
        return url
    }

    public func recentFrames(within seconds: Int, limit: Int) -> [URL] {
        guard limit > 0 else { return [] }

        let now = Date()
        let entries = (try? frameEntries()) ?? []
            .filter { now.timeIntervalSince($0.modifiedAt) <= TimeInterval(seconds) }
            .sorted { $0.modifiedAt > $1.modifiedAt }

        return Array(entries.prefix(limit)).map(\.url)
    }

    public func prune() throws {
        let now = Date()
        let entries = try frameEntries().sorted { $0.modifiedAt > $1.modifiedAt }

        let cutoff = now.addingTimeInterval(-TimeInterval(retentionSeconds))
        for entry in entries where entry.modifiedAt < cutoff {
            try? FileManager.default.removeItem(at: entry.url)
        }

        let remaining = try frameEntries().sorted { $0.modifiedAt > $1.modifiedAt }
        if remaining.count > maxFrames {
            for entry in remaining.suffix(remaining.count - maxFrames) {
                try? FileManager.default.removeItem(at: entry.url)
            }
        }
    }

    private func frameEntries() throws -> [FrameEntry] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: paths.frameBufferDirectory.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: paths.frameBufferDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return urls.compactMap { url in
            guard url.pathExtension.lowercased() == "jpg" else { return nil }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]) else {
                return nil
            }
            guard values.isRegularFile == true else { return nil }
            return FrameEntry(url: url, modifiedAt: values.contentModificationDate ?? .distantPast)
        }
    }

    private func downscaleIfNeeded(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let width = image.width
        let height = image.height
        let largest = max(width, height)

        guard largest > maxDimension else {
            return image
        }

        let scale = CGFloat(maxDimension) / CGFloat(largest)
        let targetWidth = max(1, Int(CGFloat(width) * scale))
        let targetHeight = max(1, Int(CGFloat(height) * scale))

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()
    }
}

private struct FrameEntry {
    let url: URL
    let modifiedAt: Date
}
