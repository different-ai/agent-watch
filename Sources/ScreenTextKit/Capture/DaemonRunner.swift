import AppKit
import Foundation
import os

@MainActor
public final class DaemonRunner {
    private let pipeline: CapturePipeline
    private let idleInterval: TimeInterval
    private let logger = Logger(subsystem: "com.differentai.screentext", category: "daemon")

    private var observer: NSObjectProtocol?
    private var timer: Timer?

    public init(pipeline: CapturePipeline, idleInterval: TimeInterval) {
        self.pipeline = pipeline
        self.idleInterval = idleInterval
    }

    public func run() -> Never {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.capture(trigger: .appSwitch)
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: idleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.capture(trigger: .idle)
            }
        }

        capture(trigger: .manual)
        logger.info("Daemon started")

        RunLoop.main.run()
        fatalError("Run loop exited unexpectedly")
    }

    private func capture(trigger: CaptureTrigger) {
        do {
            let outcome = try pipeline.capture(trigger: trigger)
            switch outcome {
            case .stored(let record):
                logger.debug("Stored capture for \(record.appName, privacy: .public)")
            case .skippedDuplicate:
                logger.debug("Skipped duplicate capture")
            case .skippedNoText:
                logger.debug("Skipped capture with no text")
            }
        } catch {
            logger.error("Capture failure: \(error.localizedDescription, privacy: .public)")
        }
    }
}
